import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_controller.dart';
import '../core/cloud_sync.dart';
import '../core/library_repository.dart';
import '../core/library_rules.dart';
import '../core/models.dart';
import '../core/task_reminder_service.dart';
import '../core/task_rules.dart';

const _libraryMapUrl = 'https://www.google.com/maps/search/?api=1&query=Bing%C3%B6l+%C3%9Cniversitesi+Selahaddin-i+Eyyubi+K%C3%BCt%C3%BCphanesi';

String _date(DateTime? value) => value == null ? 'Henüz doğrulanmadı' :
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

Future<void> _open(BuildContext context, String value) async {
  final allowed = isLibraryUrl(value) || value == 'tel:+904262160019' || value == 'mailto:kutuphane@bingol.edu.tr' || value == _libraryMapUrl;
  if (!allowed) { return; }
  try {
    if (await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication)) { return; }
  } catch (_) { /* Show a recoverable error below. */ }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}
class _LibraryScreenState extends State<LibraryScreen> {
  final _repository = LibraryRepository();
  LibraryFeed? _feed;
  bool _loading = true;
  String? _error;
  String _newsQuery = '';
  String _resourceQuery = '';
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    if (mounted) { setState(() { _loading = true; _error = null; }); }
    final cached = await _repository.cached();
    if (!mounted) { return; }
    if (_feed == null && cached != null) { setState(() => _feed = cached); }
    try {
      final result = await _repository.refresh();
      if (mounted) { setState(() => _feed = result); }
    } catch (_) {
      if (mounted) { setState(() => _error = 'Güncel bilgiler alınamadı. Varsa önceki kayıt gösteriliyor.'); }
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), ...children,
    ]))),
  );
  Widget _link(String title, String url, {IconData icon = Icons.open_in_new}) =>
      ListTile(contentPadding: EdgeInsets.zero, title: Text(title), trailing: Icon(icon), onTap: () => _open(context, url));
  void _article(LibraryArticle article) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Kütüphane duyurusu')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(article.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12), Text(_date(article.publishedAt)), const SizedBox(height: 20),
        SelectableText(article.body.isEmpty ? 'Duyuru metni alınamadı. Resmî sayfadan okuyabilirsiniz.' : article.body),
        const SizedBox(height: 16), const Text('Kaynak özeti. Tam metin, görseller ve ekler resmî sayfadadır.'),
        const SizedBox(height: 12), FilledButton.icon(onPressed: () => _open(context, article.url),
          icon: const Icon(Icons.open_in_new), label: const Text('Resmî duyuruyu aç')),
      ]),
    )));
  }
  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final key = librarySearchKey(_newsQuery);
    final resourceKey = librarySearchKey(_resourceQuery);
    final news = feed?.news.where((item) => librarySearchKey('${item.title} ${item.body}').contains(key)).toList() ?? [];
    final resources = libraryResources.where((item) => librarySearchKey('${item.title} ${item.description}').contains(resourceKey));
    return DefaultTabController(length: 4, child: Scaffold(
      appBar: AppBar(title: const Text('Kütüphane'), actions: [
        IconButton(tooltip: 'Yenile', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ], bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Rehber'), Tab(text: 'Duyurular'),
        Tab(text: 'Kaynaklar'), Tab(text: 'İade hatırlatmalarım')])),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        Expanded(child: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Selahaddin-i Eyyubi Kütüphanesi', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8), const Text('Bağımsız öğrenci rehberi. Kaynak: Bingöl Üniversitesi kütüphanesi.'),
            const SizedBox(height: 18),
            _section('Katalog ve kütüphane hesabım', [
              const Text('Kitap arama, raf bilgisi, ödünç kayıtları ve süre uzatma üniversitenin Yordam sisteminde yapılır. Kampüs360 hesabınızdan ayrıdır.'),
              _link('Katalog tarama ve hesabım', libraryCatalogUrl),
            ]),
            _section('Çalışma saatleri', [
              Text(feed?.hours.isNotEmpty == true ? feed!.hours : 'Saat bilgisi henüz alınamadı. Resmî kaynağı açabilirsiniz.'),
              const SizedBox(height: 10), Text('Son başarılı kontrol: ${_date(feed?.hoursCheckedAt)}'),
              if (feed?.hoursStale == true) const Text('Kayıt güncel olmayabilir.'),
              const SizedBox(height: 8), const Text('Yayımlanan programdır. Sınav, tatil ve özel duyurular değişiklik getirebilir.'),
              _link('Güncel saatlerin kaynağı', libraryHoursUrl),
            ]),
            _section('Ödünç alma rehberi', [
              const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Üyelik ve öğrenci kartı'),
                children: [Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Üyelik ve ödünç işlemleri için üniversite kimlik kartınızla kütüphaneye başvurabilirsiniz. Yeni öğrencilerin üyelikleri toplu olarak oluşturulabilir.'))]),
              const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Kitabı rafta bulma'),
                children: [Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Katalogda kitap adı, yazar veya konuyla arama yapın. Kütüphane, raf/yer bilgisi ve ödünç durumunu kontrol edin. Bulamazsanız ödünç verme bankosuna danışın.'))]),
              const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('İade tarihi ve süre uzatma'),
                children: [Padding(padding: EdgeInsets.only(bottom: 12), child: Text('İade tarihini ve uzatma hakkınızı Yordam hesabından kontrol edin. Buradaki kişisel hatırlatma, resmî iade kaydınızı veya ödünç sürenizi değiştirmez.'))]),
              _link('Kurallar ve sıkça sorulan sorular', libraryFaqUrl),
            ]),
            _section('İletişim', [
              const Text('Selahaddin-i Eyyübi Mah. Üniversite Cad. No: 1, Bingöl'),
              _link('0 (426) 216 00 19', 'tel:+904262160019', icon: Icons.call_outlined),
              _link('kutuphane@bingol.edu.tr', 'mailto:kutuphane@bingol.edu.tr', icon: Icons.email_outlined),
              _link('Kütüphaneyi haritada bul', _libraryMapUrl, icon: Icons.map_outlined),
              _link('Kütüphane web sitesi', libraryHomeUrl),
            ]),
          ]),
          ListView(padding: const EdgeInsets.all(16), children: [
            TextField(decoration: const InputDecoration(labelText: 'Duyurularda ara', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => _newsQuery = value)),
            const SizedBox(height: 12), Text('Son başarılı kontrol: ${_date(feed?.newsCheckedAt)}'),
            if (feed?.newsStale == true) const Text('Duyurular güncel olmayabilir.'),
            if (news.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Gösterilecek duyuru yok. Yenilemeyi deneyin veya resmî kaynağı açın.')),
            ...news.map((item) => Card(child: ListTile(title: Text(item.title), subtitle: Text(_date(item.publishedAt)), trailing: const Icon(Icons.chevron_right), onTap: () => _article(item)))),
            _link('Tüm resmî duyurular', libraryHomeUrl),
          ]),
          ListView(padding: const EdgeInsets.all(16), children: [
            TextField(decoration: const InputDecoration(labelText: 'Kaynak rehberinde ara', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => _resourceQuery = value)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Kaynak türlerini burada inceleyin. Yayın ve veri tabanı hizmetleri sağlayıcının sayfasında açılır. Kurum hesabı veya kampüs erişimi gerekebilir.')),
            if (resources.isEmpty) const Text('Eşleşen kaynak türü yok.'),
            ...resources.map((item) => Card(child: ListTile(title: Text(item.title), subtitle: Text(item.description), trailing: const Icon(Icons.open_in_new), onTap: () => _open(context, item.url)))),
          ]),
          const LibraryReturnsView(),
        ])),
      ]),
    ));
  }
}

class LibraryReturnsView extends StatelessWidget {
  const LibraryReturnsView({super.key});
  Future<void> _remove(BuildContext context, AppController app, StudentTask task) async {
    final owner = CloudSync.userId;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hatırlatmayı sil?'), content: Text(task.title), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
    ]));
    if (confirmed == true && context.mounted && owner == CloudSync.userId && app.signedIn) { app.removeTask(task.id); }
  }
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tasks = app.tasks.where(isLibraryReturn).toList()..sort(compareTasks);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Kitap adını ve resmî hesabınızda gördüğünüz iade tarihini kendiniz ekleyin. Kayıtlar hesabınızla eşitlenir ve ajandada görev olarak da görünür.'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: app.signedIn ? () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const LibraryReturnForm())) : null,
        icon: const Icon(Icons.add), label: const Text('İade hatırlatması ekle')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () async {
        final result = await TaskReminderService.instance.requestPermission();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result ? 'Telefon bildirim izni açık. Profilde hatırlatmalar da açık olmalıdır.' : 'Bu cihazda izin alınamadı. Bildirimler ekranını ve telefon ayarlarını kontrol edin.')));
        }
      }, icon: const Icon(Icons.notifications_outlined), label: const Text('Telefon bildirim izni')),
      const SizedBox(height: 8), const Text('Mevcut görev hatırlatmaları kullanılır: uygun tarihler için 1 gün önce, 1 saat önce ve seçilen saatte. İşletim sistemi gecikme uygulayabilir.'),
      const SizedBox(height: 16),
      if (tasks.isEmpty) const Text('Henüz iade hatırlatmanız yok.'),
      ...tasks.map((task) => Card(child: ListTile(
        leading: Checkbox(value: task.done, onChanged: (value) => app.setTaskDone(task.id, value ?? false)),
        title: Text(task.title), subtitle: Text('${_date(task.date)} · ${task.hour}\n${task.done ? 'İade edildi' : taskIsOverdue(task, DateTime.now()) ? 'İade tarihi geçti' : 'Bekliyor'}'),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => LibraryReturnForm(edit: task))),
        trailing: IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(context, app, task)),
      ))),
      const SizedBox(height: 14), _ReturnSyncStatus(app: app),
    ]);
  }
}
class _ReturnSyncStatus extends StatelessWidget {
  const _ReturnSyncStatus({required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(app.syncing ? 'Senkronize ediliyor…' : app.lastSyncError != null ? 'Senkronizasyon başarısız. Kayıtlar cihazda bekliyor.' : app.hasPendingChanges ? 'Değişiklikler senkronizasyon bekliyor.' : 'Hesabınızla senkronize'),
    OutlinedButton.icon(onPressed: app.syncing ? null : () async {
      final success = await app.syncNow();
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Senkronizasyon tamamlandı.' : 'Senkronizasyon tamamlanamadı. Tekrar deneyin.'))); }
    }, icon: const Icon(Icons.sync), label: const Text('Senkronize et')),
  ]);
}

class LibraryReturnForm extends StatefulWidget {
  const LibraryReturnForm({super.key, this.edit});
  final StudentTask? edit;
  @override
  State<LibraryReturnForm> createState() => _LibraryReturnFormState();
}
class _LibraryReturnFormState extends State<LibraryReturnForm> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _dateValue;
  late TimeOfDay _time;
  String? _owner;
  bool _saving = false;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    final now = taskTurkeyNow(DateTime.now());
    _title = TextEditingController(text: edit?.title ?? '');
    _note = TextEditingController(text: edit?.description ?? '');
    _dateValue = edit?.date ?? DateTime(now.year, now.month, now.day + 7);
    final parts = edit?.hour.split(':');
    _time = parts != null && parts.length == 2 ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 16, minute: int.tryParse(parts[1]) ?? 0) : const TimeOfDay(hour: 16, minute: 0);
    _owner = CloudSync.userId;
  }
  @override
  void dispose() { _title.dispose(); _note.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) { return; }
    final app = AppScope.of(context);
    if (!app.signedIn || _owner != CloudSync.userId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hesap değişti. Sayfayı yeniden açın.')));
      return;
    }
    final edit = widget.edit;
    if (edit != null && !app.tasks.any((task) => task.id == edit.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt artık mevcut değil.')));
      return;
    }
    final hour = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    final task = StudentTask(id: edit?.id ?? '$libraryReturnPrefix${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(), course: 'Kütüphane · Kitap iadesi',
      date: DateTime(_dateValue.year, _dateValue.month, _dateValue.day), hour: hour,
      room: 'Kütüphane', isExam: false, description: _note.text.trim(), done: edit?.done ?? false);
    if (libraryReturnDuplicate(task, app.tasks)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aynı kitap ve saat için hatırlatma zaten var.')));
      return;
    }
    setState(() => _saving = true);
    if (taskIsOverdue(task, DateTime.now())) {
      final keep = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Geçmiş tarih seçildi'), content: const Text('Bu saat geçti. Yine de kaydetmek istiyor musunuz?'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Düzelt')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ]));
      if (!mounted) { return; }
      if (keep != true) { setState(() => _saving = false); return; }
    }
    if (!mounted) { return; }
    if (_owner != CloudSync.userId || !app.signedIn) { setState(() => _saving = false); return; }
    if (edit == null) { app.addTask(task); } else { app.updateTask(task); }
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.edit == null ? 'İade hatırlatması' : 'Hatırlatmayı düzenle')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Resmî hesabınızdaki iade tarihini kontrol ederek girin. Seçilen saat kişisel hatırlatma saatidir.'),
      const SizedBox(height: 16),
      TextFormField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Kitap adı'),
        validator: (value) => value == null || value.trim().isEmpty ? 'Kitap adını yazın.' : null),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('İade tarihi'), subtitle: Text(_date(_dateValue)), trailing: const Icon(Icons.calendar_month), onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _dateValue, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null && mounted) { setState(() => _dateValue = picked); }
      }),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Hatırlatma saati'), subtitle: Text(_time.format(context)), trailing: const Icon(Icons.schedule), onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: _time);
        if (picked != null && mounted) { setState(() => _time = picked); }
      }),
      TextField(controller: _note, maxLength: 500, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Kişisel not (isteğe bağlı)')),
      const SizedBox(height: 20), FilledButton(onPressed: _saving ? null : _save, child: const Text('Kaydet')),
    ])),
  );
}
