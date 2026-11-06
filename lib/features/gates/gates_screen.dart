import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

/// Daftar pintu air dan riwayat command terakhir.
class GatesScreen extends ConsumerWidget {
  const GatesScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    final AsyncValue<List<GateCommand>> commands = ref.watch(commandsProvider);

    final Widget content = devices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) =>
          Center(child: Text('Gagal memuat perangkat: $error')),
      data: (List<Device> list) {
        final List<Device> gates = list
            .where((Device d) => d.isGate)
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Pintu air',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/rules'),
                  icon: const Icon(Icons.rule_outlined, size: 18),
                  label: const Text('Aturan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (gates.isEmpty)
              const EmptyState(message: 'Belum ada pintu air terdaftar.')
            else
              ...gates.map(
                (Device gate) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GateCard(gate: gate),
                ),
              ),
            const SizedBox(height: 8),
            SectionCard(
              title: 'Riwayat command',
              subtitle: 'ACK ≠ gerakan fisik selesai',
              child: commands.when(
                loading: () => const LinearProgressIndicator(),
                error: (Object error, StackTrace? stack) =>
                    Text('Riwayat tidak tersedia: $error'),
                data: (List<GateCommand> items) => items.isEmpty
                    ? const EmptyState(message: 'Belum ada command.')
                    : Column(
                        children: items
                            .take(8)
                            .map(
                              (GateCommand command) =>
                                  _CommandRow(command: command),
                            )
                            .toList(growable: false),
                      ),
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
      appBar: AppBar(title: const Text('Operasional')),
      body: content,
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.gate});

  final Device gate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: gate.name,
      subtitle: 'Mode ${gate.mode.label} • ${gate.firmware ?? 'firmware n/a'}',
      trailing: DataStateChip(state: gate.dataState),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: 'Posisi terukur',
                  value: '${(gate.positionPercent ?? 0).toStringAsFixed(0)}%',
                  caption: 'Feedback perangkat',
                  state: gate.dataState,
                ),
              ),
              Expanded(
                child: MetricTile(
                  label: 'Baterai',
                  value: gate.batteryPercent == null
                      ? 'n/a'
                      : Formatters.percent(gate.batteryPercent!),
                  caption: 'Uplink ${Formatters.relative(gate.lastSeen)}',
                  state: gate.dataState,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/gates/${gate.id}'),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Detail & kendali'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command});

  final GateCommand command;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (command.status) {
      CommandStatus.executed => Brand.teal,
      CommandStatus.failed ||
      CommandStatus.rejected ||
      CommandStatus.timedOut => Brand.critical,
      _ => Brand.warning,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${command.gateId} • ${command.action} '
                  '${command.targetPositionPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${Formatters.dateTime(command.createdAt)} • ${command.reason}',
                  style: const TextStyle(fontSize: 11, color: Brand.neutral),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              command.status.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
