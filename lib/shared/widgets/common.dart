import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../models/enums.dart';

/// Chip status data yang wajib muncul di setiap kartu pengukuran.
class DataStateChip extends StatelessWidget {
  const DataStateChip({required this.state, super.key});

  final DataState state;

  Color get _color {
    switch (state) {
      case DataState.live:
        return Brand.teal;
      case DataState.stale:
        return Brand.warning;
      case DataState.offline:
        return Brand.critical;
      case DataState.simulation:
        return Brand.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Kartu bagian dengan judul dan aksi opsional.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Brand.neutral),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Metrik ringkas berlabel satuan dan waktu ukur.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.state,
    this.caption,
    super.key,
  });

  final String label;
  final String value;
  final String? caption;
  final DataState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Brand.neutral),
              ),
            ),
            DataStateChip(state: state),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: Brand.forestGreen),
        ),
        if (caption != null)
          Text(
            caption!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Brand.neutral),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(icon, size: 36, color: Brand.neutral),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Brand.neutral),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner jujur tentang mode simulasi.
class SimulationBanner extends StatelessWidget {
  const SimulationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Brand.warning.withValues(alpha: 0.15),
      child: Row(
        children: <Widget>[
          const Icon(Icons.science_outlined, size: 16, color: Brand.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODE SIMULASI — data demo, bukan pengukuran lapangan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Brand.darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Brand.critical.withValues(alpha: 0.12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 16, color: Brand.critical),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Brand.forestGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.label,
        style: const TextStyle(
          color: Brand.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({required this.severity, super.key});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (severity) {
      AlertSeverity.critical => Brand.critical,
      AlertSeverity.warning => Brand.warning,
      AlertSeverity.info => Brand.teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.displayName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Menampilkan timestamp dalam WITA + status kualitas.
class TimestampLine extends StatelessWidget {
  const TimestampLine({required this.at, super.key});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${Formatters.dateTime(at)} ${AppConfig.timezoneOffsetLabel}',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Brand.neutral),
    );
  }
}

class DisclaimerText extends StatelessWidget {
  const DisclaimerText({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Brand.softGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: Brand.forestGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppConfig.aiDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
