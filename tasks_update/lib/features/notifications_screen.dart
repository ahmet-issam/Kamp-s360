import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/campus_backend.dart';
import '../core/cloud_sync.dart';
import '../core/models.dart';
import '../core/task_rules.dart';
import '../core/task_reminder_service.dart';
import 'agenda_screen.dart';
import '../core/support_notification_store.dart';
import '../core/theme.dart';
import '../core/widgets/shared.dart';
import 'campus_news_screen.dart';
import 'support_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupportNotificationStore _support = SupportNotificationStore.instance;
  String filter = 'Tümü';
  bool unreadOnly = false;

  static const _filters = ['Tümü', 'Dersler', 'Destek'];

  void _markAllRead(AppController app) {
    app.readAllNotices();
    _support.markAllRead();
  }

  String _dateLabel(DateTime? value) {
    if (value == null) { return ''; }
    final date = value.toLocal();
    final hours = date.hour.toString().padLeft(2, '0');
    final minutes = date.minute.toString().padLeft(2, '0');
    return '${dateTr(date)} $hours:$minutes';
  }

  Future<void> _openReply(StudentSupportTicket ticket) async {
    _support.markRead(ticket);
    if (!mounted) { return; }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yönetici Yanıtı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.subject,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(ticket.adminReply ?? ''),
              if (ticket.repliedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  _dateLabel(ticket.repliedAt),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) { openScreen(context, const SupportScreen()); }
            },
            child: const Text('Destek Sayfası'),
          ),
        ],
      ),
    );
  }

  Widget _replyCard(StudentSupportTicket ticket) {
    final read = _support.isRead(ticket);
    final colors = Theme.of(context).colorScheme;
    final reply = ticket.adminReply?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Panel(
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _openReply(ticket),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ColorIcon(Icons.support_agent_outlined, index: 0, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Destek yanıtı: ${ticket.subject}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!read)
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: colors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reply,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill('Destek', color: colors.primary),
                        if (ticket.repliedAt != null)
                          Text(
                            _dateLabel(ticket.repliedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: CampusVisuals.of(context).muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeCard(AppController app, CampusNotice notice) {
    final read = app.readNoticeIds.contains(notice.id);
    final category = notice.category;
    final icon = category == 'Duyurular'
        ? Icons.campaign_outlined
        : category == 'Dersler'
            ? Icons.menu_book_outlined
            : category == 'Sistem'
                ? Icons.settings_outlined
                : Icons.local_library_outlined;
    final index = category == 'Duyurular'
        ? 0
        : category == 'Dersler'
            ? 1
            : category == 'Sistem'
                ? 4
                : 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Panel(
        child: InkWell(
          onTap: () {
            app.readNotice(notice.id);
            final taskId = taskIdFromNotice(notice.id);
            final matching = app.tasks.where((task) => task.id == taskId);
            if (matching.isNotEmpty) {
              final task = matching.first;
              openScreen(context, TaskFormScreen(isExam: task.isExam, edit: task));
            } else {
              showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
                title: Text(notice.title), content: Text(notice.body),
                actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Kapat'))],
              ));
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColorIcon(icon, index: index, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!read)
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: Theme.of(context).colorScheme.tertiary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notice.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Pill(category, color: CampusVisuals.of(context).accent(index)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: CampusVisuals.of(context).muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return AnimatedBuilder(
      animation: _support,
      builder: (context, _) {
        final notices = app.notices
            .where((notice) => (filter == 'Tümü' || notice.category == filter) &&
                (!unreadOnly || !app.readNoticeIds.contains(notice.id)))
            .toList();
        final replies = filter == 'Dersler'
            ? <StudentSupportTicket>[]
            : _support.replies.where((ticket) => !unreadOnly || !_support.isRead(ticket)).toList();
        final hasItems = notices.isNotEmpty || replies.isNotEmpty;

        return RefreshIndicator(
          onRefresh: () async {
            app.refreshTaskNotices();
            await _support.refresh(showLoading: false);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            children: [
              const ScreenHeading(
                title: 'Hatırlatmalar',
                subtitle: 'Ders hatırlatmaları ve destek yanıtlarınız.',
                art: false,
              ),
              const _TaskReminderSettings(),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
                title: const Text('Yalnızca okunmamış'), value: unreadOnly,
                onChanged: (value) => setState(() => unreadOnly = value)),
              Row(
                children: [
                  const Expanded(
                    child: Text('Sınav, ödev ve destek bildirimleriniz'),
                  ),
                  TextButton(
                    onPressed: () => _markAllRead(app),
                    child: const Text(
                      'Tümünü Okundu Yap',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => openScreen(context, const CampusNewsScreen()),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Kampüs Duyurularını Gör'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _filters.map((value) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          value == 'Destek' && _support.unreadCount > 0
                              ? 'Destek (${_support.unreadCount})'
                              : value,
                        ),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 11),
              if (_support.loading) const LinearProgressIndicator(),
              if (_support.error != null && filter != 'Dersler')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextButton.icon(
                    onPressed: () => _support.refresh(),
                    icon: const Icon(Icons.refresh),
                    label: Text(_support.error!),
                  ),
                ),
              if (filter == 'Destek' && CloudSync.userId == null)
                const EmptyHint('Destek yanıtlarını görmek için giriş yapın.'),
              if (!hasItems && !_support.loading &&
                  !(filter == 'Destek' && CloudSync.userId == null))
                const EmptyHint('Henüz bir bildirim yok.'),
              for (final reply in replies) _replyCard(reply),
              for (final notice in notices) _noticeCard(app, notice),
              if (filter == 'Destek' && CloudSync.userId != null)
                TextButton.icon(
                  onPressed: () => _support.refresh(showLoading: false),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Destek yanıtlarını yenile'),
                ),
            ],
          ),
        );
      },
    );
  }
}


class _TaskReminderSettings extends StatelessWidget {
  const _TaskReminderSettings();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final service = TaskReminderService.instance;
    return AnimatedBuilder(animation: service, builder: (context, _) => Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
            title: const Text('Sınav ve ödev hatırlatmaları'),
            value: app.notificationsEnabled, onChanged: app.setNotifications),
          Text(service.supported
              ? 'Telefon hatırlatmaları 1 gün önce, 1 saat önce ve görev saatinde planlanır. Saatler Türkiye saatidir.'
              : 'Tarayıcıda hatırlatmalar uygulama içinden gösterilir. Telefon bildirimlerini Android veya iOS uygulamasında kullanabilirsin.'),
          if (service.supported) ...[
            const SizedBox(height: 8),
            Text(service.scheduling ? 'Telefon hatırlatmaları güncelleniyor…'
                : '${service.scheduledCount} telefon hatırlatması planlandı. En yakın 60 hatırlatma tutulur.'),
            if (service.permissionGranted != true)
              const Text('Telefon bildirimleri için izin gerekli.'),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                onPressed: !app.notificationsEnabled || service.scheduling ? null : () async {
                  final ok = await service.requestPermission();
                  if (!context.mounted) { return; }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                    ok ? 'Bildirim izni etkin.' : 'Bildirim izni verilmedi. Telefon ayarlarını kontrol edin.')));
                },
                icon: const Icon(Icons.notifications_active_outlined), label: const Text('Bildirim izni')),
              TextButton.icon(
                onPressed: !app.notificationsEnabled || service.scheduling ? null : () async {
                  final ok = await service.testNotification();
                  if (!context.mounted) { return; }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                    ok ? 'Deneme bildirimi gönderildi.' : 'Bildirim gösterilemedi. İzinleri kontrol edin.')));
                },
                icon: const Icon(Icons.send_outlined), label: const Text('Deneme bildirimi')),
            ]),
          ],
          if (service.error != null) Text(service.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      )),
    ));
  }
}
