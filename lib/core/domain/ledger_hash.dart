import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../shared/models/models.dart';

/// Hash chaining sederhana untuk Water Ledger.
///
/// Ini bukan blockchain: hanya rantai hash append-only untuk mendeteksi
/// perubahan/pemutusan riwayat.
class LedgerHash {
  const LedgerHash._();

  static const String genesisHash = 'GENESIS';

  static String computeHash({
    required String prevHash,
    required Map<String, dynamic> payload,
  }) {
    final String canonical = _canonical(payload);
    return sha256.convert(utf8.encode('$prevHash|$canonical')).toString();
  }

  static String hashForEntry(LedgerEntry entry) =>
      computeHash(prevHash: entry.prevHash, payload: entry.toHashPayload());

  /// Memverifikasi rantai berurutan; entri pertama harus menunjuk GENESIS.
  static LedgerVerification verify(List<LedgerEntry> entries) {
    if (entries.isEmpty) {
      return const LedgerVerification(
        valid: true,
        checkedEntries: 0,
        brokenEntryId: null,
        message: 'Ledger kosong.',
      );
    }
    String expectedPrev = genesisHash;
    for (final LedgerEntry entry in entries) {
      if (entry.prevHash != expectedPrev) {
        return LedgerVerification(
          valid: false,
          checkedEntries: entries.indexOf(entry),
          brokenEntryId: entry.id,
          message: 'Rantai hash terputus pada entri ${entry.id}.',
        );
      }
      if (hashForEntry(entry) != entry.hash) {
        return LedgerVerification(
          valid: false,
          checkedEntries: entries.indexOf(entry),
          brokenEntryId: entry.id,
          message: 'Isi entri ${entry.id} tidak cocok dengan hash-nya.',
        );
      }
      expectedPrev = entry.hash;
    }
    return LedgerVerification(
      valid: true,
      checkedEntries: entries.length,
      brokenEntryId: null,
      message: 'Rantai hash valid untuk ${entries.length} entri.',
    );
  }

  static String _canonical(Object? value) {
    if (value is Map<String, dynamic>) {
      final List<String> keys = value.keys.toList()..sort();
      return '{${keys.map((String k) => '"$k":${_canonical(value[k])}').join(',')}}';
    }
    if (value is List<dynamic>) {
      return '[${value.map(_canonical).join(',')}]';
    }
    if (value is String) {
      return jsonEncode(value);
    }
    return jsonEncode(value);
  }
}

class LedgerVerification {
  const LedgerVerification({
    required this.valid,
    required this.checkedEntries,
    required this.brokenEntryId,
    required this.message,
  });

  final bool valid;
  final int checkedEntries;
  final String? brokenEntryId;
  final String message;
}
