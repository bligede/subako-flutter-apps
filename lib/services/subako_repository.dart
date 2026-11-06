import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

/// Kontrak data SUBAKO.
///
/// Implementasi demo (tanpa Firebase) dan Firebase memakai kontrak yang sama
/// agar UI, aturan, dan pengujian tidak menduplikasi logika.
abstract class SubakoRepository {
  UserProfile? get currentUser;

  Stream<UserProfile?> authStateChanges();

  Future<UserProfile> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  Stream<List<Site>> watchSites();

  Stream<List<Device>> watchDevices(String siteId);

  Stream<TelemetrySnapshot> watchTelemetry(String deviceId);

  Stream<List<Alert>> watchAlerts(String siteId);

  Stream<List<WaterRule>> watchRules(String siteId);

  Stream<List<LedgerEntry>> watchLedger(String siteId);

  Stream<List<GateCommand>> watchCommands(String siteId);

  Future<GateCommand> requestGateCommand({
    required String gateId,
    required String siteId,
    required double targetPositionPercent,
    required String reason,
  });

  Future<void> acknowledgeAlert(String alertId);

  Future<WaterRule> createDraftRule({
    required String siteId,
    required String tempek,
    required double allocationShare,
    required String scheduleLabel,
    required String parumanReference,
    required DateTime effectiveFrom,
    required DateTime effectiveTo,
  });

  Future<WaterRule> submitRule(String ruleId);

  Future<WaterRule> approveAndPublishRule(String ruleId);

  /// Verifikasi rantai hash ledger sisi server.
  Future<bool> verifyLedger(String siteId);
}

/// Exception domain yang siap ditampilkan ke pengguna.
class SubakoException implements Exception {
  const SubakoException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Aturan minimum sebelum command aktuator boleh dibuat di sisi klien.
///
/// Validasi final tetap di Cloud Functions; ini hanya guard UX.
class CommandPreconditions {
  const CommandPreconditions({
    required this.role,
    required this.deviceState,
    required this.gateMode,
    required this.hasActiveRule,
  });

  final UserRole role;
  final DataState deviceState;
  final GateMode gateMode;
  final bool hasActiveRule;

  List<String> get violations {
    final List<String> issues = <String>[];
    if (role == UserRole.farmerViewer) {
      issues.add('Peran Petani tidak boleh mengirim perintah pintu.');
    }
    if (gateMode == GateMode.manual) {
      issues.add('Mode MANUAL fisik aktif; aplikasi tidak boleh menimpa.');
    }
    if (gateMode == GateMode.fault) {
      issues.add('Gate dalam FAULT; periksa interlock dan E-STOP.');
    }
    if (deviceState != DataState.live) {
      issues.add('Data perangkat tidak LIVE; perintah tidak boleh dikirim.');
    }
    if (!hasActiveRule) {
      issues.add('Tidak ada aturan air PUBLISHED yang berlaku.');
    }
    return issues;
  }

  bool get isAllowed => violations.isEmpty;
}
