import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/schedule_rules.dart';
import '../core/widgets/shared.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int day = DateTime.now().weekday;
  @override Widget build(BuildContext context) {
    final app = AppScope.of(context);
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final list = scheduleForDay(app.schedule, day);
    final conflicts = list.where((a) => list.any((b) => scheduleOverlaps(a, b))).map((item) => item.id).toSet();
    final minutes = scheduleDuration(list);
    return ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: [
      const ScreenHeading(title: 'Ders Programı', subtitle: 'Kendi haftalık ders planını oluştur.'),
      Row(children: [
        Expanded(child: Text('${list.length} ders · ${minutes ~/ 60} sa ${minutes % 60} dk')),
        TextButton.icon(onPressed: () => setState(() => day = DateTime.now().weekday),
          icon: const Icon(Icons.today), label: const Text('Bugün')),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(7, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: day == i + 1 ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: () => setState(() => day = i + 1),
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 65,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(names[i], textAlign: TextAlign.center, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: day == i + 1 ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyLarge?.color,
                  )),
                ),
              ),
            ),
          ),
        ))),
      ),
      const SizedBox(height: 15),
      FilledButton.icon(
        onPressed: () async {
          final addedDay = await Navigator.of(context).push<int>(
            MaterialPageRoute<int>(builder: (_) => CourseFormScreen(initialDay: day)),
          );
          if (addedDay == null || !context.mounted) { return; }
          setState(() => day = addedDay);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ders kaydedildi.')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ders Ekle'),
      ),
      const SizedBox(height: 10),
      if (app.cloudAccount) Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(child: Text(
            app.syncing ? 'Buluta kaydediliyor…' :
            app.hasPendingChanges ? 'Buluta gönderilmeyi bekliyor' :
            app.lastSyncError != null ? 'Senkronizasyon tamamlanamadı' : 'Hesabınızla senkronize',
          )),
          TextButton.icon(
            onPressed: app.syncing ? null : () async {
              final ok = await app.syncNow();
              if (!context.mounted) { return; }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Ders programı hesabınıza kaydedildi.' :
                'Senkronizasyon başarısız: ${app.lastSyncError ?? 'Bağlantıyı kontrol edin.'}'),
              ));
            },
            icon: const Icon(Icons.sync),
            label: const Text('Senkronize Et'),
          ),
        ]),
      ),
      if (app.lastSyncError != null) Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text('Senkronizasyon: ${app.lastSyncError}',
            style: const TextStyle(color: Colors.red)),
      ),
      const SizedBox(height: 15),
      if (list.isEmpty) const EmptyHint('Bu güne ders eklenmedi.', icon: Icons.event_note_outlined)
      else ...list.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Panel(
          color: Theme.of(context).brightness == Brightness.dark ? null : CampusVisuals.of(context).tint(c.colorIndex),
          child: Column(children: [
            Row(children: [ColorIcon(Icons.menu_book_rounded, index: c.colorIndex, size: 46), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${c.start} – ${c.end}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                Text([c.room, c.faculty].where((e) => e.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium),
                if (c.teacher.isNotEmpty) Text(c.teacher, style: Theme.of(context).textTheme.bodyMedium),
                if (conflicts.contains(c.id)) Text('Başka bir dersle saat çakışması var',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ])),
              PopupMenuButton<String>(tooltip: 'Ders işlemleri', onSelected: (s) {
                if (s == 'edit') { _editCourse(context, c); }
                if (s == 'remove') { _confirmDelete(context, c); }
              }, itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'remove', child: Text('Sil')),
              ]),
            ]),
          ])))),
      Panel(child: ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.date_range_outlined, color: Theme.of(context).colorScheme.primary),
          title: const Text('Haftalık Programı Görüntüle'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openScreen(context, const WeeklyScheduleScreen()))),
      const SizedBox(height: 16),
      SectionLabel(title: 'Günün Özeti', icon: Icons.insights_outlined),
      const SizedBox(height: 10),
      Row(children: [
        _Summary('${list.length}', 'Ders'), const SizedBox(width: 8),
        _Summary('${list.map((e) => e.room).where((e) => e.isNotEmpty).toSet().length}', 'Derslik'),
        const SizedBox(width: 8),
        _Summary('${list.map((e) => e.teacher).where((e) => e.isNotEmpty).toSet().length}', 'Öğretmen'),
      ]),
    ]);
  }

  Future<void> _editCourse(BuildContext context, ClassSession course) async {
    final editedDay = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => CourseFormScreen(edit: course)),
    );
    if (mounted && editedDay != null) { setState(() => day = editedDay); }
  }

  Future<void> _confirmDelete(BuildContext context, ClassSession course) async {
    final result = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Dersi sil?'), content: Text(course.title), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
    ]));
    if (result == true && context.mounted) {
      final app = AppScope.of(context);
      app.deleteCourse(course.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${course.title} silindi.'),
        action: SnackBarAction(label: 'Geri Al', onPressed: () {
          if (!app.schedule.any((item) => item.id == course.id)) {
            app.addCourse(course);
          }
        }),
      ));
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.count, this.label);
  final String count, label;
  @override Widget build(BuildContext context) => Expanded(child: Panel(padding: const EdgeInsets.all(12),
      child: Column(children: [Text(count, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: TextStyle(fontSize: 11, color: CampusVisuals.of(context).muted))])));
}

class WeeklyScheduleScreen extends StatelessWidget {
  const WeeklyScheduleScreen({super.key});
  @override Widget build(BuildContext context) {
    final items = AppScope.of(context).schedule;
    const names = ['','Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'];
    return Scaffold(appBar: AppBar(title: const Text('Haftalık Ders Programı')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (var day=1;day<=7;day++) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(names[day], style: Theme.of(context).textTheme.titleLarge)),
            ...scheduleForDay(items, day).map((e) => Card(
              child: ListTile(
                leading: Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                title: Text(e.title),
                subtitle: Text([
                  '${e.start} – ${e.end}', e.room, e.teacher,
                  if (items.any((other) => scheduleOverlaps(e, other))) 'Saat çakışması',
                ].where((value) => value.isNotEmpty).join(' · ')),
                onTap: () => Navigator.of(context).push<int>(
                    MaterialPageRoute<int>(builder: (_) => CourseFormScreen(edit: e))),
              ),
            )),
            if (!items.any((e)=>e.day == day)) const Padding(
                padding: EdgeInsets.only(bottom: 5), child: Text('Ders yok')),
          ],
        ]));
  }
}

class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({super.key, this.edit, this.initialDay = 1});
  final ClassSession? edit;
  final int initialDay;
  @override State<CourseFormScreen> createState() => _CourseFormScreenState();
}
class _CourseFormScreenState extends State<CourseFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, room, faculty, teacher;
  late int day;
  late TimeOfDay start, end;
  late int colorIndex;
  bool _saving = false;
  @override void initState() {
    super.initState();
    final v = widget.edit;
    title=TextEditingController(text: v?.title ?? '');
    room=TextEditingController(text: v?.room ?? '');
    faculty=TextEditingController(text: v?.faculty ?? '');
    teacher=TextEditingController(text: v?.teacher ?? '');
    day=(v?.day ?? widget.initialDay).clamp(1, 7).toInt();
    start=_parseTime(v?.start ?? '09:00');
    end=_parseTime(v?.end ?? '10:00');
    colorIndex=v?.colorIndex ?? 0;
  }
  TimeOfDay _parseTime(String value) {
    final minutes = scheduleMinutes(value) ?? 540;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }
  String _format(TimeOfDay d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  @override void dispose() {title.dispose();room.dispose();faculty.dispose();teacher.dispose();super.dispose();}
  Future<void> _saveCourse() async {
    if (_saving || !form.currentState!.validate()) {
      return;
    }
    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bitiş saati başlangıçtan sonra olmalı.')));
      return;
    }
    final app = AppScope.of(context);
    final course = ClassSession(
      id: widget.edit?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.text.trim(), day: day, start: _format(start), end: _format(end),
      room: room.text.trim(), faculty: faculty.text.trim(),
      teacher: teacher.text.trim(), colorIndex: colorIndex,
    );
    if (scheduleDuplicate(course, app.schedule)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bu ders aynı gün ve saatte zaten kayıtlı.')));
      return;
    }
    setState(() => _saving = true);
    final conflicts = app.schedule.where((item) => scheduleOverlaps(course, item)).toList();
    if (conflicts.isNotEmpty) {
      final keep = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Ders saatleri çakışıyor'),
        content: SingleChildScrollView(child: Text(conflicts.map((item) =>
          '${item.title} (${item.start} – ${item.end})').join('\n'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Saati düzenle')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yine de kaydet')),
        ],
      ));
      if (!mounted) {
        return;
      }
      if (keep != true) {
        setState(() => _saving = false);
        return;
      }
    }
    if (widget.edit == null) {
      app.addCourse(course);
    } else {
      app.updateCourse(course);
    }
    if (mounted) {
      Navigator.pop(context, day);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'Yeni Ders' : 'Dersi Düzenle')),
      body: Form(key: form, child: ListView(padding: const EdgeInsets.all(18), children: [
        TextFormField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText:'Ders adı'),
            validator:(v)=>v == null || v.trim().isEmpty ? 'Ders adı gerekli' : null),
        DropdownButtonFormField<int>(initialValue: day, decoration: const InputDecoration(labelText:'Gün'),
            items: List.generate(7,(i)=>DropdownMenuItem(value:i+1,child:Text(
                ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'][i]))),
            onChanged:(v)=>setState(()=>day=v ?? day)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            final result=await showTimePicker(context: context, initialTime: start);
            if(result!=null && mounted) { setState(()=>start=result); }
          },icon: const Icon(Icons.schedule),label:Text('Başlangıç ${_format(start)}'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () async {
            final result=await showTimePicker(context: context, initialTime: end);
            if(result!=null && mounted) { setState(()=>end=result); }
          },icon: const Icon(Icons.schedule),label:Text('Bitiş ${_format(end)}'))),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: room, maxLength: 80, decoration: const InputDecoration(labelText:'Derslik')),
        TextFormField(controller: faculty, maxLength: 100, decoration: const InputDecoration(labelText:'Fakülte')),
        TextFormField(controller: teacher, maxLength: 100, decoration: const InputDecoration(labelText:'Öğretim elemanı')),
        DropdownButtonFormField<int>(initialValue: colorIndex, decoration: const InputDecoration(labelText:'Renk'),
            items: List.generate(5,(i)=>DropdownMenuItem(value:i,child:Row(children: [
              Icon(Icons.circle,color:CampusVisuals.of(context).accent(i)), const SizedBox(width: 8),Text('Renk ${i+1}')]))),
            onChanged:(v)=>setState(()=>colorIndex=v ?? 0)),
        const SizedBox(height: 16),
        FilledButton.icon(icon: const Icon(Icons.save),
          label: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
          onPressed: _saving ? null : _saveCourse),
      ])));
}
