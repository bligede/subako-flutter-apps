import 'package:flutter_test/flutter_test.dart';
import 'package:subako/core/domain/command_state_machine.dart';
import 'package:subako/core/domain/freshness.dart';
import 'package:subako/core/domain/ledger_hash.dart';
import 'package:subako/core/security/permissions.dart';
import 'package:subako/shared/models/enums.dart';
import 'package:subako/shared/models/models.dart';

LedgerEntry _entry({
  required String id,
  required String prev,
  required DateTime at,
  double volume = 10,
}) {
  final LedgerEntry draft = LedgerEntry(
    id: id,
    siteId: 'site-sangeh',
    tempek: 'Tempek Kaja',
    gateId: 'gate-01',
    ruleId: 'rule-1',
    ruleVersion: 1,
    recordedAt: at,
    volumeCubicMeter: volume,
    actor: 'operator',
    source: 'TEST',
    prevHash: prev,
    hash: '',
  );
  return LedgerEntry(
    id: draft.id,
    siteId: draft.siteId,
    tempek: draft.tempek,
    gateId: draft.gateId,
    ruleId: draft.ruleId,
    ruleVersion: draft.ruleVersion,
    recordedAt: draft.recordedAt,
    volumeCubicMeter: draft.volumeCubicMeter,
    actor: draft.actor,
    source: draft.source,
    prevHash: draft.prevHash,
    hash: LedgerHash.hashForEntry(draft),
  );
}

void main() {
  group('Permissions', () {
    test('petani tidak boleh mengirim command pintu', () {
      expect(
        Permissions.can(UserRole.farmerViewer, Permissions.sendGateCommand),
        isFalse,
      );
      expect(
        Permissions.can(UserRole.farmerViewer, Permissions.viewLedger),
        isTrue,
      );
    });

    test('operator boleh command tetapi tidak menyetujui aturan', () {
      expect(
        Permissions.can(UserRole.operator, Permissions.sendGateCommand),
        isTrue,
      );
      expect(Permissions.canApproveRule(UserRole.operator), isFalse);
    });

    test('admin Mikiko tidak otomatis berwenang alokasi air', () {
      expect(Permissions.canApproveRule(UserRole.mikikoAdmin), isFalse);
      expect(Permissions.canDecideAllocation(UserRole.mikikoAdmin), isFalse);
      expect(
        Permissions.can(UserRole.mikikoAdmin, Permissions.manageDevices),
        isTrue,
      );
    });

    test('hanya Pekaseh yang boleh menyetujui aturan', () {
      expect(Permissions.canApproveRule(UserRole.pekaseh), isTrue);
    });
  });

  group('CommandStateMachine', () {
    test('alur normal sampai EXECUTED diizinkan', () {
      expect(
        CommandStateMachine.canTransition(
          CommandStatus.created,
          CommandStatus.validating,
        ),
        isTrue,
      );
      expect(
        CommandStateMachine.canTransition(
          CommandStatus.acknowledged,
          CommandStatus.executed,
        ),
        isTrue,
      );
    });

    test('ACK tidak boleh langsung dianggap EXECUTED dari SENT', () {
      expect(
        CommandStateMachine.canTransition(
          CommandStatus.sent,
          CommandStatus.executed,
        ),
        isFalse,
      );
    });

    test('status terminal tidak dapat berpindah lagi', () {
      expect(
        CommandStateMachine.canTransition(
          CommandStatus.executed,
          CommandStatus.queued,
        ),
        isFalse,
      );
      expect(
        CommandStateMachine.canTransition(
          CommandStatus.rejected,
          CommandStatus.queued,
        ),
        isFalse,
      );
    });

    test('transisi tidak sah melempar StateError', () {
      expect(
        () => CommandStateMachine.transition(
          CommandStatus.created,
          CommandStatus.executed,
        ),
        throwsStateError,
      );
    });
  });

  group('LedgerHash', () {
    test('rantai valid terverifikasi', () {
      final DateTime t0 = DateTime.utc(2026, 11, 1, 1);
      final LedgerEntry a = _entry(
        id: 'l1',
        prev: LedgerHash.genesisHash,
        at: t0,
      );
      final LedgerEntry b = _entry(
        id: 'l2',
        prev: a.hash,
        at: t0.add(const Duration(hours: 1)),
      );
      final LedgerVerification result = LedgerHash.verify(<LedgerEntry>[a, b]);
      expect(result.valid, isTrue);
      expect(result.checkedEntries, 2);
    });

    test('perubahan volume memutus verifikasi', () {
      final DateTime t0 = DateTime.utc(2026, 11, 1, 1);
      final LedgerEntry a = _entry(
        id: 'l1',
        prev: LedgerHash.genesisHash,
        at: t0,
      );
      final LedgerEntry tampered = LedgerEntry(
        id: a.id,
        siteId: a.siteId,
        tempek: a.tempek,
        gateId: a.gateId,
        ruleId: a.ruleId,
        ruleVersion: a.ruleVersion,
        recordedAt: a.recordedAt,
        volumeCubicMeter: 999,
        actor: a.actor,
        source: a.source,
        prevHash: a.prevHash,
        hash: a.hash,
      );
      final LedgerVerification result = LedgerHash.verify(<LedgerEntry>[
        tampered,
      ]);
      expect(result.valid, isFalse);
      expect(result.brokenEntryId, 'l1');
    });

    test('prev hash salah terdeteksi', () {
      final LedgerEntry a = _entry(
        id: 'l1',
        prev: 'BUKAN-GENESIS',
        at: DateTime.utc(2026, 11, 1),
      );
      expect(LedgerHash.verify(<LedgerEntry>[a]).valid, isFalse);
    });
  });

  group('Freshness', () {
    final DateTime now = DateTime.utc(2026, 11, 6, 12);

    test('LIVE untuk data baru', () {
      expect(
        Freshness.evaluate(now.subtract(const Duration(minutes: 1)), now: now),
        DataState.live,
      );
    });

    test('STALE untuk data berumur jam', () {
      expect(
        Freshness.evaluate(now.subtract(const Duration(hours: 2)), now: now),
        DataState.stale,
      );
    });

    test('OFFLINE untuk data sangat lama', () {
      expect(
        Freshness.evaluate(now.subtract(const Duration(days: 2)), now: now),
        DataState.offline,
      );
    });

    test('SIMULATION menang atas umur data', () {
      expect(
        Freshness.evaluate(now, now: now, simulated: true),
        DataState.simulation,
      );
    });

    test('hanya LIVE yang aman untuk command', () {
      expect(Freshness.isSafeForCommand(DataState.live), isTrue);
      expect(Freshness.isSafeForCommand(DataState.stale), isFalse);
    });
  });
}
