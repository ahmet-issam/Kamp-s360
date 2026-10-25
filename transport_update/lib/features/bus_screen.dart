import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_controller.dart';

const _hospitalSource =
    'https://bingoleah.saglik.gov.tr/TR-129833/iletisim.html';
const _municipalityContact = 'https://bingol.bel.tr/tr/iletisim';
const _universitySite = 'https://www.bingol.edu.tr/';

bool _transportSource(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || !uri.hasAuthority ||
      uri.userInfo.isNotEmpty || uri.hasPort) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'bingol.edu.tr' || host.endsWith('.bingol.edu.tr') ||
      host == 'bingol.bel.tr' || host == 'www.bingol.bel.tr' ||
      host == 'bingoleah.saglik.gov.tr';
}

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});
  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.of(context).loadCampusContent();
      }
    });
  }

  Future<void> _launch(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Link unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı. Tekrar deneyin.')),
        );
      }
    }
  }

  void _source(String value) {
    if (_transportSource(value)) {
      _launch(Uri.parse(value));
    }
  }

  void _map(String destination) {
    _launch(Uri.https('www.google.com', '/maps/search/', {
      'api': '1', 'query': destination,
    }));
  }

  void _directions(String destination) {
    _launch(Uri.https('www.google.com', '/maps/dir/', {
      'api': '1', 'destination': destination,
    }));
  }

  Widget _panel({required String title, required Widget child, IconData? icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _route(String title, List<String> steps) {
    return _panel(title: title, icon: Icons.alt_route, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < steps.length; index++)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, child: Text('${index + 1}')),
              const SizedBox(width: 12),
              Expanded(child: Text(steps[index])),
            ],
          )),
        TextButton.icon(
          onPressed: () => _source(_hospitalSource),
          icon: const Icon(Icons.open_in_new), label: const Text('Hastanenin ulaşım rehberi'),
        ),
      ],
    ));
  }

  Widget _page(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final service = app.busService;
    const campus = 'Bingöl Üniversitesi Rektörlüğü, Bingöl, Türkiye';
    const hospital = 'Bingöl Devlet Hastanesi, Saray Mahallesi Hasan Basri Caddesi No 66 Bingöl';
    return DefaultTabController(length: 3, child: Scaffold(
      appBar: AppBar(
        title: const Text('Ulaşım'),
        actions: [IconButton(
          tooltip: 'Bilgileri yenile',
          onPressed: app.campusLoading ? null : app.loadCampusContent,
          icon: const Icon(Icons.refresh),
        )],
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Kampüs'), Tab(text: 'Güzergâh rehberi'), Tab(text: 'Servis duyuruları'),
        ]),
      ),
      body: TabBarView(children: [
        _page([
          _panel(title: 'Bingöl Üniversitesi', icon: Icons.school_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Merkez kampüse gitmek için haritadan başlangıç noktanı ve ulaşım türünü seç.'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => _directions(campus),
                  icon: const Icon(Icons.directions), label: const Text('Kampüse yol tarifi')),
              TextButton.icon(onPressed: () => _map(campus),
                  icon: const Icon(Icons.map_outlined), label: const Text('Kampüsü haritada aç')),
              const Text('Yol tarifi Google Maps uygulamasında veya tarayıcıda açılır.'),
            ])),
          _panel(title: 'Hat ve ücret bilgileri', icon: Icons.directions_bus_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Güncel hat, durak ve bilet tarifesini Bingöl Belediyesi üzerinden öğrenebilirsin.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => _source(_municipalityContact),
                  icon: const Icon(Icons.open_in_new), label: const Text('Belediye iletişim sayfası')),
              const SelectableText('Bingöl Belediyesi: +90 426 213 12 18'),
              const SizedBox(height: 8),
              const Text('Bu bölümde canlı araç konumu ve kalkış saati verisi bulunmuyor.'),
            ])),
        ]),
        _page([
          Text('Hastaneye ulaşım', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Aşağıdaki bağlantılar hastanenin yayımladığı ulaşım rehberine dayanır. Ara durakların tamamını göstermez.'),
          const SizedBox(height: 14),
          _route('Üniversite / Yüksekokul → Hastane', const [
            'Üniversite güzergâhındaki araçla DSİ Durağı’na git.',
            'Sanayi/Hastaneler güzergâhına aktarma yap.',
            'Hastane Durağı’nda in.',
          ]),
          _route('Merkez → Hastane', const [
            'Merkez Ulu Camii önündeki duraktan Sanayi/Hastaneler aracına bin.',
            'Hastane Durağı’nda in.',
          ]),
          _route('Kültür Mahallesi → Hastane', const [
            'Çapakçur Viyadüğü bağlantı noktasındaki durağa git.',
            'Sanayi/Hastaneler aracına aktarma yapıp Hastane Durağı’nda in.',
          ]),
          _route('Uydukent → Hastane', const [
            'Uydukent/Sebze Hali aracıyla DSİ Durağı’na git.',
            'Sanayi/Hastaneler aracına aktarma yapıp Hastane Durağı’nda in.',
          ]),
          OutlinedButton.icon(onPressed: () => _map(hospital),
              icon: const Icon(Icons.location_on_outlined), label: const Text('Hastaneyi haritada aç')),
          const SizedBox(height: 8),
          const Text('Kaynak: Bingöl Devlet Hastanesi · 10 Haziran 2026'),
        ]),
        RefreshIndicator(onRefresh: app.loadCampusContent, child: _page([
          if (app.campusLoading) const LinearProgressIndicator(),
          if (app.campusError != null) ...[
            const SizedBox(height: 12),
            const Text('Ulaşım bilgileri yenilenemedi. Tekrar deneyin.'),
            const SizedBox(height: 12),
          ],
          if (service != null)
            _panel(title: service.title, icon: Icons.campaign_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SelectableText(service.description),
                const SizedBox(height: 12),
                Text('Yayımlanan güncelleme: ${service.updatedAt.day}.${service.updatedAt.month}.${service.updatedAt.year}'),
                if (service.sourceUrl != null && _transportSource(service.sourceUrl!))
                  TextButton.icon(onPressed: () => _source(service.sourceUrl!),
                      icon: const Icon(Icons.open_in_new), label: const Text('Duyuru kaynağını aç')),
              ]))
          else if (!app.campusLoading)
            _panel(title: 'Servis ve ring duyuruları', icon: Icons.info_outline,
              child: const Text('Uygulamada yayımlanmış servis veya ring bilgisi bulunmuyor. Üniversitenin duyurularını kontrol edebilirsin.')),
          OutlinedButton.icon(onPressed: () => _source(_universitySite),
              icon: const Icon(Icons.open_in_new), label: const Text('Üniversitenin resmî sitesi')),
          TextButton.icon(onPressed: app.campusLoading ? null : app.loadCampusContent,
              icon: const Icon(Icons.refresh), label: const Text('Duyuruları yenile')),
        ])),
      ]),
    ));
  }
}
