import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand.dart';
import '../../core/domain/ledger_hash.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  LedgerVerification? _verification;
  bool _checking = false;

  Future<void> _verify(List<LedgerEntry> entries) async {
    setState(() => _checking = true);
    final List<LedgerEntry> chronological = entries.reversed.toList();
    final LedgerVerification result = LedgerHash.verify(chronological);
    if (!mounted) {
      return;
    }
    setState(() {
      _verification = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LedgerEntry>> ledger = ref.watch(ledgerProvider);
    final Widget content = ledger.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) =>
          Center(child: Text('Gagal memuat ledger: $error')),
      data: (List<LedgerEntry> entries) => ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SectionCard(
            title: 'Buku Catatan Air',
            subtitle:
                'Append-only dengan rantai hash. Ini bukan blockchain; '
                'koreksi dibuat sebagai entri baru yang tertaut.',
            trailing: TextButton(
              onPressed: _checking ? null : () => _verify(entries),
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verifikasi'),
            ),
            child: _verification == null
                ? const Text(
                    'Tekan Verifikasi untuk memeriksa rantai hash seluruh '
                    'entri yang dimuat.',
                    style: TextStyle(fontSize: 12, color: Brand.neutral),
                  )
                : Row(
                    children: <Widget>[
                      Icon(
                        _verification!.valid
                            ? Icons.verified_outlined
                            : Icons.gpp_bad_outlined,
                        color: _verification!.valid
                            ? Brand.teal
                            : Brand.critical,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _verification!.message,
                          style: TextStyle(
                            color: _verification!.valid
                                ? Brand.forestGreen
                                : Brand.critical,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const EmptyState(
              message: 'Belum ada catatan air.',
              icon: Icons.menu_book_outlined,
            )
          else
            ...entries.map(
              (LedgerEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LedgerCard(entry: entry),
              ),
            ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Buku Catatan Air')),
      body: content,
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '${entry.gateId} • ${Formatters.volume(entry.volumeCubicMeter)}',
      subtitle: '${Formatters.dateTime(entry.recordedAt)} • ${entry.tempek}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Brand.softGreen,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          entry.source,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Brand.forestGreen,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Aturan ${entry.ruleId} v${entry.ruleVersion} • aktor ${entry.actor}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'hash ${entry.hash.substring(0, 12)}… ← prev '
            '${entry.prevHash == LedgerHash.genesisHash ? 'GENESIS' : '${entry.prevHash.substring(0, 10)}…'}',
            style: const TextStyle(fontSize: 10, color: Brand.neutral),
          ),
          if (entry.correctionOf != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Koreksi dari ${entry.correctionOf}',
              style: const TextStyle(fontSize: 11, color: Brand.warning),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ekspor CSV sederhana; dipakai layar laporan.
String ledgerToCsv(List<LedgerEntry> entries) {
  final StringBuffer buffer = StringBuffer(
    'id,waktu_utc,tempek,gate,rule,versi,volume_m3,aktor,sumber,hash\n',
  );
  for (final LedgerEntry entry in entries) {
    buffer.writeln(
      '"${entry.id}","${entry.recordedAt.toIso8601String()}","${entry.tempek}",'
      '"${entry.gateId}","${entry.ruleId}",${entry.ruleVersion},'
      '${entry.volumeCubicMeter.toStringAsFixed(3)},"${entry.actor}",'
      '"${entry.source}","${entry.hash}"',
    );
  }
  return buffer.toString();
}

/// Status kualitas data untuk kartu ledger (selalu historis).
const DataState ledgerDataState = DataState.live;
