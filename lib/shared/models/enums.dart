/// Peran pengguna pada platform SUBAKO.
enum UserRole {
  farmerViewer('farmer_viewer', 'Petani'),
  operator('operator', 'Operator'),
  pekaseh('pekaseh', 'Pekaseh'),
  mikikoAdmin('mikiko_admin', 'Admin Mikiko'),
  platformAdmin('platform_admin', 'Admin Platform');

  const UserRole(this.wireName, this.label);

  final String wireName;
  final String label;

  static UserRole fromWire(String? value) {
    return UserRole.values.firstWhere(
      (UserRole role) => role.wireName == value,
      orElse: () => UserRole.farmerViewer,
    );
  }
}

/// Status kualitas/freshness data yang wajib terlihat di UI.
enum DataState {
  live('LIVE', 'Data terukur terbaru'),
  stale('STALE', 'Data lama, perlu verifikasi'),
  offline('OFFLINE', 'Perangkat tidak terhubung'),
  simulation('SIMULATION', 'Data simulasi, bukan pengukuran lapangan');

  const DataState(this.label, this.description);

  final String label;
  final String description;

  static DataState fromWire(String? value) {
    return DataState.values.firstWhere(
      (DataState state) => state.label == value,
      orElse: () => DataState.offline,
    );
  }
}

/// Mode fisik controller pintu air.
enum GateMode {
  auto('AUTO'),
  manual('MANUAL'),
  hold('HOLD'),
  idle('IDLE'),
  fault('FAULT');

  const GateMode(this.label);

  final String label;

  static GateMode fromWire(String? value) {
    return GateMode.values.firstWhere(
      (GateMode mode) => mode.label == value,
      orElse: () => GateMode.idle,
    );
  }
}

/// Siklus hidup command aktuator.
///
/// ACK hanya berarti perangkat menerima perintah; EXECUTED hanya boleh diisi
/// dari feedback posisi/penyelesaian fisik.
enum CommandStatus {
  created('CREATED'),
  validating('VALIDATING'),
  queued('QUEUED'),
  sent('SENT'),
  acknowledged('ACKNOWLEDGED'),
  executed('EXECUTED'),
  rejected('REJECTED'),
  expired('EXPIRED'),
  failed('FAILED'),
  timedOut('TIMED_OUT'),
  cancelled('CANCELLED');

  const CommandStatus(this.label);

  final String label;

  bool get isTerminal => const <CommandStatus>{
    CommandStatus.executed,
    CommandStatus.rejected,
    CommandStatus.expired,
    CommandStatus.failed,
    CommandStatus.timedOut,
    CommandStatus.cancelled,
  }.contains(this);

  static CommandStatus fromWire(String? value) {
    return CommandStatus.values.firstWhere(
      (CommandStatus status) => status.label == value,
      orElse: () => CommandStatus.created,
    );
  }
}

/// Status siklus aturan alokasi air.
enum RuleStatus {
  draft('DRAFT'),
  submitted('SUBMITTED'),
  approved('APPROVED'),
  published('PUBLISHED'),
  expired('EXPIRED'),
  revoked('REVOKED');

  const RuleStatus(this.label);

  final String label;

  bool get isActive => this == RuleStatus.published;

  static RuleStatus fromWire(String? value) {
    return RuleStatus.values.firstWhere(
      (RuleStatus status) => status.label == value,
      orElse: () => RuleStatus.draft,
    );
  }
}

/// Tingkat keparahan alert.
enum AlertSeverity {
  critical('CRITICAL', 'Kritis'),
  warning('WARNING', 'Peringatan'),
  info('INFO', 'Informasi');

  const AlertSeverity(this.label, this.displayName);

  final String label;
  final String displayName;

  static AlertSeverity fromWire(String? value) {
    return AlertSeverity.values.firstWhere(
      (AlertSeverity severity) => severity.label == value,
      orElse: () => AlertSeverity.info,
    );
  }
}

/// Jenis node perangkat.
enum DeviceKind {
  gate('GATE'),
  measurement('MEASUREMENT'),
  gateway('GATEWAY');

  const DeviceKind(this.label);

  final String label;

  static DeviceKind fromWire(String? value) {
    return DeviceKind.values.firstWhere(
      (DeviceKind kind) => kind.label == value,
      orElse: () => DeviceKind.measurement,
    );
  }
}
