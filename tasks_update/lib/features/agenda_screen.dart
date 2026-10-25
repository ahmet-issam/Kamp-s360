import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/task_rules.dart';
import '../core/widgets/shared.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _search = TextEditingController();
  bool _exams = true;
  String _status = 'Bekleyen';
  DateTime? _date;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(StudentTask task) async {
    final app = AppScope.of(context);
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Kaydı sil?'), content: Text(task.title), actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
      ],
    ));
    if (!mounted || ok != true) {
      return;
    }
    app.removeTask(task.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Kayıt silindi.'),
      action: SnackBarAction(label: 'Geri Al', onPressed: () {
        if (!app.tasks.any((item) => item.id == task.id)) {
          app.addTask(task);
        }
      }),
    ));
  }

  Future<void> _edit({StudentTask? task}) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => TaskFormScreen(isExam: task?.isExam ?? _exams, edit: task),
    ));
  }

  Widget _card(StudentTask task, AppController app, DateTime now) {
    final due = taskDeadline(task);
    final label = task.done ? 'Tamamlandı'
        : due == null ? 'Saati kontrol edin'
        : taskIsOverdue(task, now) ? 'Süresi geçti' : 'Bekliyor';
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(
      padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: task.done, onChanged: (value) => app.setTaskDone(task.id, value ?? false)),
            Expanded(child: InkWell(onTap: () => _edit(task: task), child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4), Text(task.course),
                const SizedBox(height: 4), Text('${dateTr(task.date)} · ${task.hour}'),
                if (task.room.isNotEmpty) Text(task.room),
              ]),
            ))),
            PopupMenuButton<String>(tooltip: 'Görev işlemleri', onSelected: (action) {
              if (action == 'edit') {
                _edit(task: task);
              } else if (action == 'delete') {
                _delete(task);
              }
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ]),
          ]),
          Text(label, style: TextStyle(color: taskIsOverdue(task, now)
              ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary)),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            TextButton(onPressed: () => _edit(task: task), child: const Text('Ayrıntıları aç')),
          ],
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final today = taskTurkeyNow(now);
    final group = app.tasks.where((task) => task.isExam == _exams).toList();
    final items = group.where((task) {
      final sameDate = _date == null || (task.date.year == _date!.year &&
          task.date.month == _date!.month && task.date.day == _date!.day);
      final status = _status == 'Tümü' || (_status == 'Bekleyen' && !task.done) ||
          (_status == 'Tamamlanan' && task.done) ||
          (_status == 'Geciken' && taskIsOverdue(task, now));
      return sameDate && status && taskMatches(task, _search.text);
    }).toList()..sort(compareTasks);
    return Scaffold(
      appBar: AppBar(title: const Text('Sınavlar ve Ödevler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Yeni Ekle'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        Text('${group.where((task) => !task.done).length} bekleyen · '
            '${group.where((task) => taskIsOverdue(task, now)).length} geciken · '
            '${group.where((task) => task.done).length} tamamlanan'),
        const SizedBox(height: 14),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: true, label: Text('Sınavlar'), icon: Icon(Icons.assignment_outlined)),
          ButtonSegment(value: false, label: Text('Ödevler'), icon: Icon(Icons.task_outlined)),
        ], selected: {_exams}, onSelectionChanged: (selection) => setState(() => _exams = selection.first)),
        const SizedBox(height: 14),
        TextField(controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: 'Başlık, ders veya açıklama ara',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Aramayı temizle',
              onPressed: () => setState(_search.clear), icon: const Icon(Icons.close)),
          )),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final value in ['Bekleyen', 'Geciken', 'Tamamlanan', 'Tümü'])
            ChoiceChip(label: Text(value), selected: _status == value,
              onSelected: (_) => setState(() => _status = value)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(label: Text(_date == null ? 'Tüm tarihler' : dateTr(_date!)),
            avatar: const Icon(Icons.calendar_today, size: 18), onPressed: () async {
              final selected = await showDatePicker(context: context,
                initialDate: _date ?? DateTime(today.year, today.month, today.day),
                firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (mounted && selected != null) {
                setState(() => _date = selected);
              }
            }),
          ActionChip(label: const Text('Bugün'), onPressed: () => setState(() =>
              _date = DateTime(today.year, today.month, today.day))),
          if (_date != null)
            ActionChip(label: const Text('Tarih filtresini kaldır'), onPressed: () => setState(() => _date = null)),
        ]),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 28),
            child: Text('Bu arama ve filtrelere uygun kayıt yok. Yeni Ekle ile sınav veya ödev ekleyebilirsin.')),
        for (final task in items) _card(task, app, now),
      ]),
    );
  }
}

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.isExam, this.edit});

  final bool isExam;
  final StudentTask? edit;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController title;
  late final TextEditingController course;
  late final TextEditingController room;
  late final TextEditingController description;
  late DateTime chosen;
  late TimeOfDay time;
  late bool _isExam;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.edit;
    title = TextEditingController(text: task?.title ?? '');
    course = TextEditingController(text: task?.course ?? '');
    room = TextEditingController(text: task?.room ?? '');
    description = TextEditingController(text: task?.description ?? '');
    final local = taskTurkeyNow(DateTime.now());
    chosen = task?.date ?? DateTime(local.year, local.month, local.day + 1);
    if (chosen.year < 2020 || chosen.year > 2100) {
      chosen = DateTime(local.year, local.month, local.day + 1);
    }
    _isExam = task?.isExam ?? widget.isExam;
    final clock = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(task?.hour ?? '10:00');
    final hour = clock == null ? 10 : int.parse(clock[1]!);
    final minute = clock == null ? 0 : int.parse(clock[2]!);
    time = TimeOfDay(hour: hour.clamp(0, 23).toInt(), minute: minute.clamp(0, 59).toInt());
  }

  @override
  void dispose() {
    title.dispose();
    course.dispose();
    room.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_saving) { return; }
    if (title.text.trim().isEmpty || course.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve ders adı gereklidir.')),
      );
      return;
    }
    final hour = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final task = StudentTask(
      id: widget.edit?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.text.trim(),
      course: course.text.trim(),
      room: room.text.trim(),
      description: description.text.trim(),
      date: DateTime(chosen.year, chosen.month, chosen.day, time.hour, time.minute),
      hour: hour,
      isExam: _isExam,
      done: widget.edit?.done ?? false,
    );
    final app = AppScope.of(context);
    if (duplicateTask(task, app.tasks)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aynı başlık, ders ve tarih için kayıt zaten var.')));
      return;
    }
    setState(() => _saving = true);
    if (!task.done && taskIsOverdue(task, DateTime.now())) {
      final keep = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Geçmiş tarih seçildi'),
        content: const Text('Bu kaydın saati geçmiş. Yine de kaydetmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Tarihi düzelt')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
        ],
      ));
      if (!mounted) { return; }
      if (keep != true) { setState(() => _saving = false); return; }
    }
    if (widget.edit == null) {
      app.addTask(task);
    } else {
      app.updateTask(task);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.edit != null
          ? 'Kaydı Düzenle'
          : _isExam
          ? 'Sınav Ekle'
          : 'Ödev Ekle'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(segments: const [
            ButtonSegment(value: true, label: Text('Sınav')),
            ButtonSegment(value: false, label: Text('Ödev')),
          ], selected: {_isExam}, onSelectionChanged: (values) => setState(() => _isExam = values.first)),
          const SizedBox(height: 12),
          TextField(
            controller: title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Başlık'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: course,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Ders adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: room,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Konum veya teslim şekli'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            minLines: 3,
            maxLines: 6,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
              hintText: 'Ödevin veya sınavın ayrıntılarını yazın...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Tarih Seç'),
                  subtitle: Text(dateTr(chosen)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: chosen,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (value != null && mounted) { setState(() => chosen = value); }
                  },
                ),
                ListTile(
                  title: const Text('Saat Seç'),
                  subtitle: Text(time.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (value != null && mounted) { setState(() => time = value); }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _saveTask,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
          ),
        ],
      ),
    ),
  );
}
