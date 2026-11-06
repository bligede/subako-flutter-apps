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

/// Detail pintu + permintaan command dengan guard peran dan prasyarat.
class GateDetailScreen extends ConsumerWidget {
  const GateDetailScreen({required this.gateId, super.key});

  final String gateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
    final AsyncValue<List<GateCommand>> commands = ref.watch(commandsProvider);
    final UserProfile? user = ref.watch(activeUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(gateId)),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) =>
            Center(child: Text('Perangkat tidak ditemukan: $error')),
        data: (List<Device> list) {
          final Device? gate = list
              .where((Device d) => d.id == gateId)
              .cast<Device?>()
              .firstWhere((Device? _) => true, orElse: () => null);
          if (gate == null) {
            return const EmptyState(message: 'Perangkat tidak ditemukan.');
          }
          final List<GateCommand> gateCommands =
              (commands.value ?? const <GateCommand>[])
                  .where((GateCommand c) => c.gateId == gateId)
                  .toList(growable: false);
          final bool canCommand =
              user != null &&
              Permissions.forUser(user, Permissions.sendGateCommand);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SectionCard(
                title: gate.name,
                subtitle:
                    '${gate.kind.label} • ${gate.firmware ?? 'firmware n/a'}',
                trailing: DataStateChip(state: gate.dataState),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MetricTile(
                            label: 'Posisi terukur',
                            value:
                                '${(gate.positionPercent ?? 0).toStringAsFixed(0)}%',
                            caption: 'Dari encoder/feedback',
                            state: gate.dataState,
                          ),
                        ),
                        Expanded(
                          child: MetricTile(
                            label: 'Mode',
                            value: gate.mode.label,
                            caption: 'Mode fisik controller',
                            state: gate.dataState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MetricTile(
                            label: 'Baterai',
                            value: gate.batteryPercent == null
                                ? 'n/a'
                                : Formatters.percent(gate.batteryPercent!),
                            state: gate.dataState,
                          ),
                        ),
                        Expanded(
                          child: MetricTile(
                            label: 'Motor',
                            value: gate.motorCurrentAmp == null
                                ? 'n/a'
                                : '${gate.motorCurrentAmp!.toStringAsFixed(1)} A',
                            state: gate.dataState,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LimitRow(
                      label: 'Limit atas',
                      active: gate.upperLimit ?? false,
                    ),
                    _LimitRow(
                      label: 'Limit bawah',
                      active: gate.lowerLimit ?? false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Kendali pintu',
                subtitle:
                    'Perintah hanya dikirim sebagai permintaan; '
                    'interlock lokal tetap berwenang.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!canCommand)
                      const Text(
                        'Peran Anda tidak memiliki izin mengirim perintah pintu. '
                        'Hubungi Operator/Pekaseh.',
                        style: TextStyle(color: Brand.neutral),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => _openCommandSheet(context, ref, gate),
                        icon: const Icon(Icons.tune),
                        label: const Text('Minta perubahan posisi'),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aplikasi tidak dapat menimpa MANUAL/FAULT/E-STOP dan '
                      'tidak menyimpan command untuk dikirim ulang saat offline.',
                      style: TextStyle(fontSize: 12, color: Brand.neutral),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Siklus command',
                subtitle: 'ACK berarti diterima, bukan selesai bergerak.',
                child: gateCommands.isEmpty
                    ? const EmptyState(
                        message: 'Belum ada command untuk gate ini.',
                      )
                    : Column(
                        children: gateCommands
                            .take(6)
                            .map(
                              (GateCommand command) =>
                                  _CommandTimeline(command: command),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCommandSheet(
    BuildContext context,
    WidgetRef ref,
    Device gate,
  ) async {
    final _CommandRequest? request =
        await showModalBottomSheet<_CommandRequest>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => _CommandSheet(gate: gate),
        );
    if (request == null) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .requestGateCommand(
            gateId: gate.id,
            siteId: ref.read(activeSiteIdProvider),
            targetPositionPercent: request.position,
            reason: request.reason,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan command dikirim. Pantau siklus statusnya.'),
        ),
      );
    } on SubakoException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Brand.neutral)),
          ),
          Icon(
            active ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 18,
            color: active ? Brand.warning : Brand.teal,
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'AKTIF' : 'normal',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CommandTimeline extends StatelessWidget {
  const _CommandTimeline({required this.command});

  final GateCommand command;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${command.action} → ${command.targetPositionPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                command.status.label,
                style: const TextStyle(fontSize: 11, color: Brand.neutral),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.dateTime(command.createdAt)} • ${command.reason}',
            style: const TextStyle(fontSize: 11, color: Brand.neutral),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                const <String>[
                      'CREATED',
                      'VALIDATING',
                      'QUEUED',
                      'SENT',
                      'ACKNOWLEDGED',
                      'EXECUTED',
                    ]
                    .map<Widget>((String step) {
                      final bool reached =
                          _order(step) <= _order(command.status.label);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: reached
                              ? Brand.teal.withValues(alpha: 0.14)
                              : Brand.neutral.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: reached ? Brand.forestGreen : Brand.neutral,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
          ),
        ],
      ),
    );
  }

  int _order(String status) {
    const List<String> sequence = <String>[
      'CREATED',
      'VALIDATING',
      'QUEUED',
      'SENT',
      'ACKNOWLEDGED',
      'EXECUTED',
    ];
    return sequence.indexOf(status);
  }
}

class _CommandRequest {
  const _CommandRequest(this.position, this.reason);

  final double position;
  final String reason;
}

class _CommandSheet extends StatefulWidget {
  const _CommandSheet({required this.gate});

  final Device gate;

  @override
  State<_CommandSheet> createState() => _CommandSheetState();
}

class _CommandSheetState extends State<_CommandSheet> {
  late double _position = widget.gate.positionPercent ?? 0;
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool blocked =
        widget.gate.mode == GateMode.manual ||
        widget.gate.mode == GateMode.fault ||
        widget.gate.dataState != DataState.live;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Permintaan posisi ${widget.gate.name}',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Mode ${widget.gate.mode.label} • data ${widget.gate.dataState.label}',
            style: const TextStyle(fontSize: 12, color: Brand.neutral),
          ),
          const SizedBox(height: 16),
          if (blocked)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Brand.critical.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Command tidak dapat dikirim: mode MANUAL/FAULT atau data '
                'perangkat tidak LIVE. Ikuti prosedur keselamatan di lapangan.',
                style: TextStyle(color: Brand.critical, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          Text('Target posisi: ${_position.toStringAsFixed(0)}%'),
          Slider(
            value: _position,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_position.toStringAsFixed(0)}%',
            onChanged: blocked
                ? null
                : (double value) => setState(() => _position = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Alasan operasional (wajib)',
              hintText: 'Contoh: penyesuaian sesuai jadwal Tempek Kaja',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Brand.critical)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: blocked
                ? null
                : () {
                    final String reason = _reason.text.trim();
                    if (reason.length < 8) {
                      setState(() {
                        _error = 'Tulis alasan minimal 8 karakter.';
                      });
                      return;
                    }
                    Navigator.of(context)
                        .pop(_CommandRequest(_position, reason));
                  },
            child: const Text('Kirim permintaan'),
          ),
        ],
      ),
    );
  }
}
