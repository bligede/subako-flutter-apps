import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';
import '../ledger/ledger_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final List<LedgerEntry> ledger =
        ref.watch(ledgerProvider).value ?? const <LedgerEntry>[];
    final List<Alert> alerts =
        ref.watch(alertsProvider).value ?? const <Alert>[];
    final List<GateCommand> commands =
        ref.watch(commandsProvider).value ?? const <GateCommand>[];
    final DateTime cutoff = DateTime.now().toUtc().subtract(
      Duration(days: _days),
    );
    final List<LedgerEntry> filtered = ledger
        .where((LedgerEntry e) => e.recordedAt.isAfter(cutoff))
        .toList(growable: false);
    final double totalVolume = filtered.fold<double>(
      0,
      (double sum, LedgerEntry e) => sum + e.volumeCubicMeter,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Salin CSV',
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: ledgerToCsv(filtered)),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CSV disalin ke clipboard.'),
                      ),
                    );
                  },
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('Harian')),
              ButtonSegment<int>(value: 7, label: Text('Mingguan')),
              ButtonSegment<int>(value: 30, label: Text('Bulanan')),
            ],
            selected: <int>{_days},
            onSelectionChanged: (Set<int> value) =>
                setState(() => _days = value.first),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title:
                'Ringkasan ${_days == 1
                    ? 'harian'
                    : _days == 7
                    ? 'mingguan'
                    : 'bulanan'}',
            subtitle: 'Periode dihitung dari waktu UTC, ditampilkan WITA.',
            child: Column(
              children: <Widget>[
                _ReportRow(
                  label: 'Total volume tercatat',
                  value: Formatters.volume(totalVolume),
                ),
                _ReportRow(label: 'Entri ledger', value: '${filtered.length}'),
                _ReportRow(
                  label: 'Command dieksekusi',
                  value:
                      '${commands.where((GateCommand c) => c.status == CommandStatus.executed).length}',
                ),
                _ReportRow(
                  label: 'Alert kritis',
                  value:
                      '${alerts.where((Alert a) => a.severity == AlertSeverity.critical).length}',
                ),
                _ReportRow(
                  label: 'Alert belum diakui',
                  value: '${alerts.where((Alert a) => !a.acknowledged).length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Keterbatasan data',
            subtitle: 'Wajib dibaca sebelum memakai laporan.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text('• Volume dihitung dari entri ledger yang tersedia.'),
                SizedBox(height: 4),
                Text('• Data hilang/stale tidak diinterpolasi.'),
                SizedBox(height: 4),
                Text('• Build simulasi tidak mewakili pengukuran lapangan.'),
                SizedBox(height: 4),
                Text('• PDF belum diimplementasikan; ekspor saat ini CSV.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Brand.neutral)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
