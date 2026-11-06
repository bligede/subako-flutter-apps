import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardSummary> summary = ref.watch(dashboardProvider);

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) => _ErrorView(message: '$error'),
      data: (DashboardSummary data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sitesProvider);
          ref.invalidate(devicesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _SiteHeader(site: data.site),
            const SizedBox(height: 12),
            _TelemetryCard(summary: data),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    label: 'Perangkat online',
                    value: '${data.onlineDevices}/${data.totalDevices}',
                    icon: Icons.router_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Rata-rata baterai',
                    value: '${data.averageBatteryPercent.toStringAsFixed(0)}%',
                    icon: Icons.battery_5_bar_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _QuickActions(hasAlerts: data.activeAlerts.isNotEmpty),
            const SizedBox(height: 12),
            _AlertsPreview(alerts: data.activeAlerts),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Peristiwa pintu terakhir',
              subtitle:
                  'Dari feedback perangkat, bukan dari perintah terkirim.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.lastGateEvents
                    .map(
                      (String event) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: Brand.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(event)),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Data ditampilkan dengan status kualitas masing-masing. '
              'Buka Monitoring untuk seri waktu dan kesehatan perangkat.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Brand.neutral),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.site});

  final Site site;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                site.name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '${site.locationLabel} • ${site.tempekCount} tempek • ${site.gateCount} pintu',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Brand.neutral),
              ),
            ],
          ),
        ),
        DataStateChip(state: site.dataState),
      ],
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final TelemetrySnapshot telemetry = summary.telemetry;
    return SectionCard(
      title: 'Kondisi air terkini',
      subtitle:
          'Diperbarui ${Formatters.relative(telemetry.recordedAt)} • ${telemetry.quality}',
      trailing: DataStateChip(state: telemetry.dataState),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: 'Level hulu',
                  value: Formatters.centimeter(telemetry.upstreamCm),
                  caption: 'Sensor node-01',
                  state: telemetry.dataState,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Level hilir',
                  value: Formatters.centimeter(telemetry.downstreamCm),
                  caption: 'Sensor node-01',
                  state: telemetry.dataState,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: 'Debit',
                  value: Formatters.literPerSecond(
                    telemetry.flowLiterPerSecond,
                  ),
                  caption: 'Ambang target mengikuti aturan aktif',
                  state: telemetry.dataState,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Waktu ukur',
                  value: Formatters.time(telemetry.recordedAt),
                  caption: AppConfig.timezoneOffsetLabel,
                  state: telemetry.dataState,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Brand.teal, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Brand.neutral),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.hasAlerts});

  final bool hasAlerts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Akses cepat',
      child: Column(
        children: <Widget>[
          _ActionTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Tanya SUBAKO AI',
            subtitle: 'Penjelasan data dan panduan (advisory)',
            onTap: () => context.push('/ai'),
          ),
          const Divider(height: 20),
          _ActionTile(
            icon: Icons.rule_outlined,
            title: 'Aturan & jadwal air',
            subtitle: 'Versi aturan yang disahkan Paruman',
            onTap: () => context.push('/rules'),
          ),
          const Divider(height: 20),
          _ActionTile(
            icon: Icons.assessment_outlined,
            title: 'Laporan',
            subtitle: 'Ringkasan harian/bulanan + ekspor CSV',
            onTap: () => context.push('/reports'),
          ),
          if (hasAlerts) ...<Widget>[
            const Divider(height: 20),
            _ActionTile(
              icon: Icons.notifications_active_outlined,
              title: 'Alert aktif',
              subtitle: 'Perlu tindak lanjut operator',
              onTap: () => context.push('/alerts'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: Brand.forestGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Brand.neutral),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Brand.neutral),
        ],
      ),
    );
  }
}

class _AlertsPreview extends StatelessWidget {
  const _AlertsPreview({required this.alerts});

  final List<Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Alert aktif',
      subtitle: '${alerts.length} belum diakui',
      trailing: TextButton(
        onPressed: () => context.push('/alerts'),
        child: const Text('Semua'),
      ),
      child: alerts.isEmpty
          ? const EmptyState(
              message: 'Tidak ada alert aktif.',
              icon: Icons.check_circle_outline,
            )
          : Column(
              children: alerts
                  .take(3)
                  .map((Alert alert) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SeverityBadge(severity: alert.severity),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  alert.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  Formatters.relative(alert.raisedAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Brand.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Brand.critical,
            ),
            const SizedBox(height: 12),
            const Text(
              'Data tidak dapat dimuat.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.neutral, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
