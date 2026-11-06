import 'package:flutter_test/flutter_test.dart';
import 'package:subako/shared/models/enums.dart';
import 'package:subako/shared/models/models.dart';

void main() {
  test('UserProfile mem-parse role dan siteIds', () {
    final UserProfile profile = UserProfile.fromMap('uid-1', <String, dynamic>{
      'name': 'Pekaseh',
      'email': 'pekaseh@subako.demo',
      'role': 'pekaseh',
      'siteIds': <String>['site-sangeh'],
    });
    expect(profile.role, UserRole.pekaseh);
    expect(profile.siteIds.single, 'site-sangeh');
  });

  test('role tidak dikenal jatuh ke farmer_viewer', () {
    expect(UserRole.fromWire('unknown'), UserRole.farmerViewer);
    expect(UserRole.fromWire(null), UserRole.farmerViewer);
  });

  test('Alert.copyWith mempertahankan field lain', () {
    final Alert alert = Alert(
      id: 'a1',
      siteId: 's1',
      deviceId: 'gate-01',
      severity: AlertSeverity.critical,
      title: 'Baterai kritis',
      evidence: '18%',
      suggestedAction: 'Ganti baterai',
      raisedAt: DateTime.utc(2026, 11, 6),
      acknowledged: false,
    );
    final Alert ack = alert.copyWith(
      acknowledged: true,
      acknowledgedBy: 'operator',
      acknowledgedAt: DateTime.utc(2026, 11, 6, 1),
    );
    expect(ack.acknowledged, isTrue);
    expect(ack.severity, AlertSeverity.critical);
    expect(ack.title, 'Baterai kritis');
  });

  test('GateCommand.copyWith hanya mengubah status', () {
    final GateCommand command = GateCommand(
      id: 'c1',
      gateId: 'gate-01',
      siteId: 's1',
      action: 'SET_POSITION',
      targetPositionPercent: 40,
      status: CommandStatus.created,
      createdAt: DateTime.utc(2026, 11, 6),
      actorUid: 'u1',
      ruleId: 'r1',
      reason: 'jadwal',
    );
    final GateCommand updated = command.copyWith(
      status: CommandStatus.acknowledged,
      updatedAt: DateTime.utc(2026, 11, 6, 0, 1),
    );
    expect(updated.status, CommandStatus.acknowledged);
    expect(updated.targetPositionPercent, 40);
    expect(updated.id, command.id);
  });

  test('LedgerEntry payload hash memuat nilai kanonik', () {
    final LedgerEntry entry = LedgerEntry(
      id: 'l1',
      siteId: 's1',
      tempek: 'Tempek Kaja',
      gateId: 'gate-01',
      ruleId: 'r1',
      ruleVersion: 2,
      recordedAt: DateTime.utc(2026, 11, 6, 1),
      volumeCubicMeter: 12.3456,
      actor: 'operator',
      source: 'TEST',
      prevHash: 'GENESIS',
      hash: 'abc',
    );
    expect(entry.toHashPayload()['volumeCubicMeter'], '12.346');
    expect(entry.toHashPayload()['ruleVersion'], 2);
  });
}
