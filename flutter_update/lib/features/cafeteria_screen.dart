import 'package:flutter/material.dart';
import '../core/cafeteria_repository.dart';
import '../core/official_links.dart';

class CafeteriaScreen extends StatefulWidget {
  const CafeteriaScreen({super.key});
  @override
  State<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends State<CafeteriaScreen> {
  final _repository = CafeteriaRepository();
  CafeteriaMenu? _menu;
  DateTime _selected = campusToday();
  bool _loading = true;
  bool _failed = false;
  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _weekdays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading && mounted) {
      setState(() => _loading = true);
    }
    if (_menu == null) {
      final cached = await _repository.cached();
      if (!mounted) {
        return;
      }
      if (cached != null) {
        setState(() => _menu = cached);
      }
    }
    try {
      final fresh = await _repository.refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _menu = fresh;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _label(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year} · ${_weekdays[date.weekday - 1]}';

  Widget _card(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = campusToday();
    final menu = _menu;
    final entries = menu?.items ?? <CampusMeal>[];
    final selectedItems = entries.where((item) => item.date == _selected);
    final meal = selectedItems.isEmpty ? null : selectedItems.first;
    final stale = menu != null &&
        DateTime.now().toUtc().difference(menu.checkedAt) > const Duration(days: 2);
    final monthDays = entries.where((item) =>
        item.date.year == _selected.year && item.date.month == _selected.month).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Yemekhane Menüsü'), actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text('Merkezi Yemekhane', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('Bingöl Üniversitesi · SKS'),
            const SizedBox(height: 18),
            if (_failed || stale)
              _card(Text(menu == null
                  ? 'Menü yüklenemedi. Tekrar deneyin veya resmî sayfayı açın.'
                  : _failed
                      ? 'Güncelleme alınamadı. Son kaydedilen menü gösteriliyor.'
                      : 'Son kontrolün üzerinden iki günden fazla geçti. Resmî sayfayı kontrol edin.')),
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_selected == today ? 'Bugünün Menüsü' : 'Seçilen Gün',
                    style: theme.textTheme.titleLarge)),
                TextButton(onPressed: () => setState(() => _selected = today),
                    child: const Text('Bugün')),
              ]),
              Row(children: [
                IconButton(tooltip: 'Önceki gün',
                    onPressed: () => setState(() => _selected = DateTime(
                        _selected.year, _selected.month, _selected.day - 1)),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _selected,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() => _selected = picked);
                    }
                  },
                  child: Text(_label(_selected), textAlign: TextAlign.center),
                )),
                IconButton(tooltip: 'Sonraki gün',
                    onPressed: () => setState(() => _selected = DateTime(
                        _selected.year, _selected.month, _selected.day + 1)),
                    icon: const Icon(Icons.chevron_right)),
              ]),
              const Divider(),
              if (meal != null)
                ...meal.dishes.map((dish) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.restaurant_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(dish, style: theme.textTheme.titleMedium)),
                  ]),
                ))
              else if (!_loading || menu != null)
                const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Bu tarih için resmî menü yayımlanmamış.')),
              if (meal == null && entries.any((item) => item.date.isAfter(_selected)))
                TextButton.icon(
                  onPressed: () => setState(() => _selected =
                      entries.firstWhere((item) => item.date.isAfter(_selected)).date),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Sonraki yayımlanan menü'),
                ),
            ])),
            if (monthDays.isNotEmpty)
              Card(margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(
                title: Text('${_months[_selected.month - 1]} ${_selected.year}'),
                subtitle: Text('${monthDays.length} gün için menü'),
                children: monthDays.map((entry) => ListTile(
                  selected: entry.date == _selected,
                  title: Text(_label(entry.date)),
                  subtitle: Text(entry.dishes.join(' · ')),
                  onTap: () => setState(() => _selected = entry.date),
                )).toList(),
              )),
            if (menu != null)
              Text('Son kaynak kontrolü: ${_label(DateTime(
                  menu.checkedAt.add(const Duration(hours: 3)).year,
                  menu.checkedAt.add(const Duration(hours: 3)).month,
                  menu.checkedAt.add(const Duration(hours: 3)).day))}',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOfficialWebsite(context, CafeteriaRepository.sourceUrl),
              icon: const Icon(Icons.open_in_new), label: const Text('Resmî yemek listesini aç'),
            ),
          ],
        ),
      ),
    );
  }
}
