import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand.dart';
import '../../core/security/permissions.dart';
import '../../core/utils/formatters.dart';
import '../../services/subako_repository.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Alert>> alerts = ref.watch(alertsProvider);
    final UserProfile? user = ref.watch(activeUserProvider);
    final bool canAck =
        user != null && Permissions.forUser(user, Permissions.acknowledgeAlert);

    final Widget content = alerts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) =>
          Center(child: Text('Gagal memuat alert: $error')),
      data: (List<Alert> items) {
        final List<Alert> open = items
            .where((Alert a) => !a.acknowledged)
            .toList(growable: false);
        final List<Alert> acknowledged = items
            .where((Alert a) => a.acknowledged)
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${open.length} alert aktif',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (open.any((Alert a) => a.severity == AlertSeverity.critical))
                  const SeverityBadge(severity: AlertSeverity.critical),
              ],
            ),
            const SizedBox(height: 12),
            if (open.isEmpty)
              const EmptyState(
                message: 'Tidak ada alert aktif.',
                icon: Icons.check_circle_outline,
              )
            else
              ...open.map(
                (Alert alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlertCard(alert: alert, canAck: canAck),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Sudah diakui',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (acknowledged.isEmpty)
              const Text(
                'Belum ada alert yang diakui.',
                style: TextStyle(fontSize: 12, color: Brand.neutral),
              )
            else
              ...acknowledged
                  .take(5)
                  .map(
                    (Alert alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertCard(alert: alert, canAck: false),
                    ),
                  ),
          ],
        );
      },
    );

    if (embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Alert')),
      body: content,
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert, required this.canAck});

  final Alert alert;
  final bool canAck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: alert.title,
      subtitle:
          '${alert.deviceId} • ${Formatters.dateTime(alert.raisedAt)} WITA',
      trailing: SeverityBadge(severity: alert.severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bukti: ${alert.evidence}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Tindakan disarankan: ${alert.suggestedAction}',
            style: const TextStyle(fontSize: 12, color: Brand.neutral),
          ),
          if (!alert.acknowledged && canAck) ...<Widget>[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(repositoryProvider).acknowledgeAlert(alert.id);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alert diakui dan tercatat pada audit.'),
                    ),
                  );
                } on SubakoException catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Akui alert'),
            ),
          ],
          if (alert.acknowledged)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Diakui oleh ${alert.acknowledgedBy ?? 'operator'} '
                '${alert.acknowledgedAt == null ? '' : '• ${Formatters.relative(alert.acknowledgedAt!)}'}',
                style: const TextStyle(fontSize: 11, color: Brand.teal),
              ),
            ),
        ],
      ),
    );
  }
}
