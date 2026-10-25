import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/note_rules.dart';

Future<bool> _removeNote(BuildContext context, String course) async {
  final app = AppScope.of(context);
  final previous = app.notes[course];
  if (previous == null) {
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Notu sil?'),
      content: Text('$course için kaydedilen not silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  // A sync can update this note while the confirmation dialog is open.
  if (app.notes[course] != previous) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Not değişti. Güncel metni kontrol edip tekrar deneyin.'),
    ));
    return false;
  }
  app.setNote(course, '');
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: const Text('Not silindi.'),
    action: SnackBarAction(label: 'Geri Al', onPressed: () {
      if (!app.notes.containsKey(course)) {
        app.setNote(course, previous);
      } else {
        messenger.showSnackBar(const SnackBar(
          content: Text('Bu konuda yeni bir not var. Üzerine yazılmadı.'),
        ));
      }
    }),
  ));
  return true;
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newNote() async {
    final title = await showDialog<String>(
      context: context, builder: (_) => const _TopicDialog(),
    );
    if (!mounted || title == null) {
      return;
    }
    final app = AppScope.of(context);
    final topic = noteTopic(title, app.noteSubjects);
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => EditNoteScreen(course: topic),
    ));
  }

  void _edit(String course) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => EditNoteScreen(course: course),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final subjects = app.noteSubjects.where((course) {
      final body = app.notes[course] ?? '';
      final hasNote = body.trim().isNotEmpty;
      return (_filter == 0 || (_filter == 1 && hasNote) ||
              (_filter == 2 && !hasNote)) &&
          noteMatches(course, body, _search.text);
    }).toList();
    final savedCount = app.notes.values.where((text) => text.trim().isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Notlarım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newNote,
        icon: const Icon(Icons.add), label: const Text('Yeni Not'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text('Ders Notlarım', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('$savedCount kayıtlı not · ${app.noteSubjects.length} ders / konu'),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Ders veya not metni ara',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty ? null : IconButton(
                tooltip: 'Aramayı temizle',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Hepsi', 'Notu olanlar', 'Boş dersler'][i]),
                selected: _filter == i,
                onSelected: (_) => setState(() => _filter = i),
              ),
          ]),
          const SizedBox(height: 12),
          const _NoteSyncStatus(),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Bu arama veya filtreye uygun kayıt yok. Yeni Not ile bir konu ekleyebilirsin.'),
            ),
          for (final course in subjects)
            Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: Icon(Icons.sticky_note_2_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(course),
              subtitle: Text(
                (app.notes[course] ?? '').trim().isEmpty
                    ? 'Henüz not eklenmedi' : app.notes[course]!,
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _edit(course),
              trailing: PopupMenuButton<String>(
                tooltip: 'Not işlemleri',
                onSelected: (action) {
                  if (action == 'edit') {
                    _edit(course);
                  } else if (action == 'delete') {
                    _removeNote(context, course);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                  if (app.notes.containsKey(course))
                    const PopupMenuItem(value: 'delete', child: Text('Notu sil')),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _TopicDialog extends StatefulWidget {
  const _TopicDialog();
  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  final _title = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _title.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Yeni Not Konusu'),
    content: Form(key: _form, child: TextFormField(
      controller: _title, autofocus: true, maxLength: 100,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      decoration: const InputDecoration(labelText: 'Ders veya konu adı'),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Konu adı gerekli' : null,
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
      FilledButton(onPressed: _submit, child: const Text('Devam')),
    ],
  );
}

class _NoteSyncStatus extends StatelessWidget {
  const _NoteSyncStatus();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.cloudAccount) {
      return const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Notlar bu cihazda saklanır.'));
    }
    final status = app.syncing ? 'Hesabınıza kaydediliyor…'
        : app.lastSyncError != null ? 'Senkronizasyon tamamlanamadı'
        : app.hasPendingChanges ? 'Senkronizasyon bekleniyor'
        : 'Hesabınızla senkronize';
    return Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(status),
        TextButton.icon(
          onPressed: app.syncing ? null : () async {
            final ok = await app.syncNow();
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
              ok ? 'Notlar hesabınıza kaydedildi.'
                  : 'Senkronizasyon tamamlanamadı. Bağlantıyı kontrol edin.',
            )));
          },
          icon: const Icon(Icons.sync), label: const Text('Senkronize Et'),
        ),
      ]),
    ));
  }
}

class EditNoteScreen extends StatefulWidget {
  const EditNoteScreen({super.key, required this.course});
  final String course;
  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _text = TextEditingController();
  String? _baseline;
  bool _allowPop = false;
  bool _busy = false;
  bool get _dirty => _baseline != null && _text.text != _baseline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_baseline == null) {
      _baseline = AppScope.of(context).notes[widget.course] ?? '';
      _text.text = _baseline!;
      _text.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _save() async {
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not metni girin. Mevcut notu kaldırmak için sil düğmesini kullanın.'),
      ));
      return false;
    }
    final app = AppScope.of(context);
    final remote = app.notes[widget.course] ?? '';
    if (remote != _baseline && remote != _text.text) {
      final overwrite = await showDialog<bool>(
        context: context, builder: (dialogContext) => AlertDialog(
          title: const Text('Kaydedilen not değişti'),
          content: const Text('Bu konu başka bir işlemde güncellendi. Düzenlediğiniz metni onun yerine kaydetmek istiyor musunuz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yerine kaydet')),
          ],
        ),
      );
      if (!mounted || overwrite != true) {
        return false;
      }
    }
    app.setNote(widget.course, _text.text);
    _baseline = _text.text;
    return true;
  }

  Future<void> _saveAndClose() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final saved = await _save();
    if (!mounted) {
      return;
    }
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not kaydedildi.')));
      await _close();
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || !_dirty) {
      return;
    }
    setState(() => _busy = true);
    final action = await showDialog<String>(
      context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text('Çıkmadan önce notu kaydetmek ister misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'stay'), child: const Text('Düzenlemeye devam et')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'discard'), child: const Text('Kaydetmeden çık')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'save'), child: const Text('Kaydet')),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (action == 'discard') {
      await _close();
    } else if (action == 'save') {
      final saved = await _save();
      if (!mounted) {
        return;
      }
      if (saved) {
        await _close();
      } else {
        setState(() => _busy = false);
      }
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final removed = await _removeNote(context, widget.course);
    if (!mounted) {
      return;
    }
    if (removed) {
      await _close();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.course), actions: [
          if (app.notes.containsKey(widget.course))
            IconButton(tooltip: 'Notu sil', onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline)),
        ]),
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(_dirty ? 'Kaydedilmemiş değişiklikler' : 'Not metni'),
            const SizedBox(height: 10),
            Expanded(child: TextField(
              controller: _text, readOnly: _busy,
              maxLines: null, expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Bu ders veya konu için notlarını yaz…',
                border: OutlineInputBorder(),
              ),
            )),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Text('${_text.text.runes.length} karakter')),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _busy || !_dirty ? null : _saveAndClose,
              icon: const Icon(Icons.save_outlined),
              label: Text(_busy ? 'İşleniyor…' : 'Notu Kaydet'),
            )),
          ]),
        )),
      ),
    );
  }
}
