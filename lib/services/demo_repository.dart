import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/domain/command_state_machine.dart';
import '../core/domain/ledger_hash.dart';
import '../shared/models/enums.dart';
import '../shared/models/models.dart';
import 'subako_repository.dart';

/// Akun demo. Hanya untuk build simulasi; bukan kredensial produksi.
const String kDemoPassword = 'Subako#2026';

/// Implementasi data simulasi yang berjalan penuh tanpa Firebase.
///
/// Semua record diberi label SIMULATION agar tidak pernah tampil sebagai
/// pengukuran lapangan.
class DemoRepository implements SubakoRepository {
  DemoRepository() {
    _seed();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _tick());
  }

  final Random _random = Random(7);
  late final StreamController<UserProfile?> _authController =
      StreamController<UserProfile?>.broadcast();
  late final StreamController<List<Device>> _devicesController =
      StreamController<List<Device>>.broadcast();
  late final StreamController<List<Alert>> _alertsController =
      StreamController<List<Alert>>.broadcast();
  late final StreamController<List<WaterRule>> _rulesController =
      StreamController<List<WaterRule>>.broadcast();
  late final StreamController<List<GateCommand>> _commandsController =
      StreamController<List<GateCommand>>.broadcast();
  late final StreamController<List<LedgerEntry>> _ledgerController =
      StreamController<List<LedgerEntry>>.broadcast();

  Timer? _timer;
  UserProfile? _user;
  late Site _site;
  final List<Device> _devices = <Device>[];
  final List<Alert> _alerts = <Alert>[];
  final List<WaterRule> _rules = <WaterRule>[];
  final List<GateCommand> _commands = <GateCommand>[];
  final List<LedgerEntry> _ledger = <LedgerEntry>[];
  late TelemetrySnapshot _telemetry;

  static const Map<String, UserProfile> _demoUsers = <String, UserProfile>{
    'petani@subako.demo': UserProfile(
      uid: 'demo-farmer',
      name: 'I Wayan Sutarja',
      email: 'petani@subako.demo',
      role: UserRole.farmerViewer,
      siteIds: <String>['site-sangeh'],
    ),
    'operator@subako.demo': UserProfile(
      uid: 'demo-operator',
      name: 'Ni Luh Ayu Pramesti',
      email: 'operator@subako.demo',
      role: UserRole.operator,
      siteIds: <String>['site-sangeh'],
    ),
    'pekaseh@subako.demo': UserProfile(
      uid: 'demo-pekaseh',
      name: 'I Made Wirawan',
      email: 'pekaseh@subako.demo',
      role: UserRole.pekaseh,
      siteIds: <String>['site-sangeh'],
    ),
    'admin@subako.demo': UserProfile(
      uid: 'demo-admin',
      name: 'Admin Mikiko',
      email: 'admin@subako.demo',
      role: UserRole.mikikoAdmin,
      siteIds: <String>['site-sangeh'],
    ),
  };

  @override
  UserProfile? get currentUser => _user;

  void _seed() {
    final DateTime now = DateTime.now().toUtc();
    _site = Site(
      id: 'site-sangeh',
      name: 'Subak Sangeh',
      village: 'Sangeh',
      regency: 'Badung',
      tempekCount: 3,
      gateCount: 2,
      dataState: DataState.simulation,
    );

    _devices.addAll(<Device>[
      Device(
        id: 'gate-01',
        name: 'Gate-01',
        siteId: _site.id,
        kind: DeviceKind.gate,
        mode: GateMode.auto,
        dataState: DataState.simulation,
        lastSeen: now,
        positionPercent: 35,
        batteryPercent: 82,
        rssi: -78,
        firmware: 'subako-fw 0.2.1',
        motorCurrentAmp: 1.4,
        upperLimit: false,
        lowerLimit: false,
      ),
      Device(
        id: 'gate-02',
        name: 'Gate-02',
        siteId: _site.id,
        kind: DeviceKind.gate,
        mode: GateMode.manual,
        dataState: DataState.simulation,
        lastSeen: now,
        positionPercent: 0,
        batteryPercent: 18,
        rssi: -102,
        firmware: 'subako-fw 0.2.0',
        motorCurrentAmp: 0,
        upperLimit: false,
        lowerLimit: true,
      ),
      Device(
        id: 'node-01',
        name: 'Node Ukur Hulu',
        siteId: _site.id,
        kind: DeviceKind.measurement,
        mode: GateMode.idle,
        dataState: DataState.simulation,
        lastSeen: now,
        batteryPercent: 91,
        rssi: -71,
        firmware: 'subako-fw 0.2.1',
      ),
      Device(
        id: 'gw-01',
        name: 'Gateway Sangeh',
        siteId: _site.id,
        kind: DeviceKind.gateway,
        mode: GateMode.idle,
        dataState: DataState.simulation,
        lastSeen: now,
        batteryPercent: 100,
        rssi: -60,
        firmware: 'chirpstack-gw 4.9',
      ),
    ]);

    _telemetry = TelemetrySnapshot(
      deviceId: 'node-01',
      upstreamCm: 42.5,
      downstreamCm: 28.1,
      flowLiterPerSecond: 18.4,
      recordedAt: now,
      dataState: DataState.simulation,
      quality: 'Baik (kalibrasi 2026-09-12)',
    );

    _rules.addAll(<WaterRule>[
      WaterRule(
        id: 'rule-2026-014',
        siteId: _site.id,
        tempek: 'Tempek Kaja',
        version: 2,
        status: RuleStatus.published,
        allocationShare: 0.45,
        scheduleLabel: 'Senin–Kamis, 06:00–10:00 WITA',
        effectiveFrom: now.subtract(const Duration(days: 4)),
        effectiveTo: now.add(const Duration(days: 10)),
        parumanReference: 'Paruman 2026-09-28/IV',
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      WaterRule(
        id: 'rule-2026-015',
        siteId: _site.id,
        tempek: 'Tempek Kelod',
        version: 1,
        status: RuleStatus.draft,
        allocationShare: 0.30,
        scheduleLabel: 'Jumat–Sabtu, 07:00–09:00 WITA',
        effectiveFrom: now.add(const Duration(days: 1)),
        effectiveTo: now.add(const Duration(days: 14)),
        parumanReference: 'Paruman 2026-10-26/II',
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
    ]);

    _alerts.addAll(<Alert>[
      Alert(
        id: 'alert-001',
        siteId: _site.id,
        deviceId: 'gate-02',
        severity: AlertSeverity.critical,
        title: 'Baterai Gate-02 kritis',
        evidence: 'Tegangan 10.4 V, 18% (ambang 20%).',
        suggestedAction:
            'Ganti/isi baterai dan verifikasi panel solar sebelum operasi.',
        raisedAt: now.subtract(const Duration(minutes: 22)),
        acknowledged: false,
      ),
      Alert(
        id: 'alert-002',
        siteId: _site.id,
        deviceId: 'node-01',
        severity: AlertSeverity.warning,
        title: 'RSSI Node Ukur Hulu melemah',
        evidence: 'RSSI -71 dBm, SNR 4.2 dB.',
        suggestedAction: 'Periksa antena dan posisi gateway.',
        raisedAt: now.subtract(const Duration(hours: 3)),
        acknowledged: true,
        acknowledgedBy: 'demo-operator',
        acknowledgedAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);

    _commands.add(
      GateCommand(
        id: 'cmd-0001',
        gateId: 'gate-01',
        siteId: _site.id,
        action: 'SET_POSITION',
        targetPositionPercent: 35,
        status: CommandStatus.executed,
        createdAt: now.subtract(const Duration(hours: 5)),
        actorUid: 'demo-operator',
        ruleId: 'rule-2026-014',
        reason: 'Menyesuaikan debit sesuai jadwal pagi.',
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
    );

    _appendLedger(
      at: now.subtract(const Duration(hours: 5)),
      gateId: 'gate-01',
      volume: 312.4,
      actor: 'demo-operator',
    );
    _appendLedger(
      at: now.subtract(const Duration(hours: 3)),
      gateId: 'gate-01',
      volume: 288.7,
      actor: 'device:node-01',
      source: 'SIMULATOR',
    );
    _appendLedger(
      at: now.subtract(const Duration(hours: 1)),
      gateId: 'gate-02',
      volume: 96.2,
      actor: 'device:node-01',
      source: 'SIMULATOR',
    );
  }

  void _appendLedger({
    required DateTime at,
    required String gateId,
    required double volume,
    required String actor,
    String source = 'USER',
  }) {
    final String prev = _ledger.isEmpty
        ? LedgerHash.genesisHash
        : _ledger.last.hash;
    final String id =
        'ledger-${(_ledger.length + 1).toString().padLeft(4, '0')}';
    final LedgerEntry draft = LedgerEntry(
      id: id,
      siteId: _site.id,
      tempek: 'Tempek Kaja',
      gateId: gateId,
      ruleId: 'rule-2026-014',
      ruleVersion: 2,
      recordedAt: at,
      volumeCubicMeter: volume,
      actor: actor,
      source: source,
      prevHash: prev,
      hash: '',
    );
    _ledger.add(
      LedgerEntry(
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
      ),
    );
  }

  void _tick() {
    final DateTime now = DateTime.now().toUtc();
    final double drift = (_random.nextDouble() - 0.5) * 1.6;
    _telemetry = TelemetrySnapshot(
      deviceId: _telemetry.deviceId,
      upstreamCm: (_telemetry.upstreamCm + drift).clamp(30, 60),
      downstreamCm: (_telemetry.downstreamCm + drift * 0.6).clamp(15, 45),
      flowLiterPerSecond: (_telemetry.flowLiterPerSecond + drift * 0.4).clamp(
        5,
        30,
      ),
      recordedAt: now,
      dataState: DataState.simulation,
      quality: _telemetry.quality,
    );
    for (int i = 0; i < _devices.length; i++) {
      final Device device = _devices[i];
      _devices[i] = Device(
        id: device.id,
        name: device.name,
        siteId: device.siteId,
        kind: device.kind,
        mode: device.mode,
        dataState: DataState.simulation,
        lastSeen: now,
        positionPercent: device.positionPercent,
        batteryPercent: device.batteryPercent,
        rssi: device.rssi,
        firmware: device.firmware,
        motorCurrentAmp: device.motorCurrentAmp,
        upperLimit: device.upperLimit,
        lowerLimit: device.lowerLimit,
      );
    }
    _devicesController.add(List<Device>.unmodifiable(_devices));
  }

  @override
  Stream<UserProfile?> authStateChanges() async* {
    yield _user;
    yield* _authController.stream;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final UserProfile? profile = _demoUsers[email.trim().toLowerCase()];
    if (profile == null || password != kDemoPassword) {
      throw const SubakoException(
        'Email atau kata sandi demo tidak sesuai.',
        code: 'invalid-credential',
      );
    }
    _user = profile;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('demo_uid', profile.uid);
    _authController.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('demo_uid');
    _authController.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Stream<List<Site>> watchSites() => Stream<List<Site>>.value(<Site>[_site]);

  @override
  Stream<List<Device>> watchDevices(String siteId) async* {
    yield List<Device>.unmodifiable(_devices);
    yield* _devicesController.stream;
  }

  @override
  Stream<TelemetrySnapshot> watchTelemetry(String deviceId) async* {
    yield _telemetry;
    yield* Stream<TelemetrySnapshot>.periodic(
      const Duration(seconds: 12),
      (_) => _telemetry,
    );
  }

  @override
  Stream<List<Alert>> watchAlerts(String siteId) async* {
    yield List<Alert>.unmodifiable(_alerts);
    yield* _alertsController.stream;
  }

  @override
  Stream<List<WaterRule>> watchRules(String siteId) async* {
    yield List<WaterRule>.unmodifiable(_rules);
    yield* _rulesController.stream;
  }

  @override
  Stream<List<LedgerEntry>> watchLedger(String siteId) async* {
    yield List<LedgerEntry>.unmodifiable(_ledger.reversed);
    yield* _ledgerController.stream;
  }

  @override
  Stream<List<GateCommand>> watchCommands(String siteId) async* {
    yield List<GateCommand>.unmodifiable(_commands.reversed);
    yield* _commandsController.stream;
  }

  @override
  Future<GateCommand> requestGateCommand({
    required String gateId,
    required String siteId,
    required double targetPositionPercent,
    required String reason,
  }) async {
    final UserProfile? user = _user;
    if (user == null) {
      throw const SubakoException('Sesi berakhir. Silakan masuk kembali.');
    }
    final Device gate = _devices.firstWhere((Device d) => d.id == gateId);
    final bool hasRule = _rules.any(
      (WaterRule rule) => rule.status == RuleStatus.published,
    );
    final CommandPreconditions preconditions = CommandPreconditions(
      role: user.role,
      deviceState: gate.dataState,
      gateMode: gate.mode,
      hasActiveRule: hasRule,
    );
    if (!preconditions.isAllowed) {
      throw SubakoException(preconditions.violations.first);
    }

    final DateTime now = DateTime.now().toUtc();
    GateCommand command = GateCommand(
      id: 'cmd-${DateTime.now().microsecondsSinceEpoch}',
      gateId: gateId,
      siteId: siteId,
      action: 'SET_POSITION',
      targetPositionPercent: targetPositionPercent,
      status: CommandStatus.created,
      createdAt: now,
      actorUid: user.uid,
      ruleId: _rules
          .firstWhere((WaterRule r) => r.status == RuleStatus.published)
          .id,
      reason: reason,
      expiresAt: now.add(const Duration(minutes: 2)),
      updatedAt: now,
    );
    _commands.add(command);
    _emitCommands();
    unawaited(_simulateCommandLifecycle(command));
    return command;
  }

  Future<void> _simulateCommandLifecycle(GateCommand command) async {
    const List<CommandStatus> path = <CommandStatus>[
      CommandStatus.validating,
      CommandStatus.queued,
      CommandStatus.sent,
      CommandStatus.acknowledged,
      CommandStatus.executed,
    ];
    CommandStatus current = command.status;
    for (final CommandStatus next in path) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!CommandStateMachine.canTransition(current, next)) {
        break;
      }
      current = CommandStateMachine.transition(current, next);
      final int index = _commands.indexWhere(
        (GateCommand c) => c.id == command.id,
      );
      if (index < 0) {
        return;
      }
      _commands[index] = _commands[index].copyWith(
        status: current,
        updatedAt: DateTime.now().toUtc(),
      );
      _emitCommands();
      if (current == CommandStatus.executed) {
        _applyGatePosition(command.gateId, command.targetPositionPercent);
        _appendLedger(
          at: DateTime.now().toUtc(),
          gateId: command.gateId,
          volume: 12.5,
          actor: _user?.uid ?? 'demo-operator',
          source: 'COMMAND',
        );
        _emitLedger();
      }
    }
  }

  void _applyGatePosition(String gateId, double position) {
    final int index = _devices.indexWhere((Device d) => d.id == gateId);
    if (index < 0) {
      return;
    }
    final Device gate = _devices[index];
    _devices[index] = Device(
      id: gate.id,
      name: gate.name,
      siteId: gate.siteId,
      kind: gate.kind,
      mode: GateMode.auto,
      dataState: gate.dataState,
      lastSeen: DateTime.now().toUtc(),
      positionPercent: position,
      batteryPercent: gate.batteryPercent,
      rssi: gate.rssi,
      firmware: gate.firmware,
      motorCurrentAmp: gate.motorCurrentAmp,
      upperLimit: position >= 100,
      lowerLimit: position <= 0,
    );
    _devicesController.add(List<Device>.unmodifiable(_devices));
  }

  void _emitCommands() => _commandsController.add(
    List<GateCommand>.unmodifiable(_commands.reversed),
  );

  void _emitLedger() =>
      _ledgerController.add(List<LedgerEntry>.unmodifiable(_ledger.reversed));

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    final int index = _alerts.indexWhere((Alert a) => a.id == alertId);
    if (index < 0) {
      return;
    }
    _alerts[index] = _alerts[index].copyWith(
      acknowledged: true,
      acknowledgedBy: _user?.uid,
      acknowledgedAt: DateTime.now().toUtc(),
    );
    _alertsController.add(List<Alert>.unmodifiable(_alerts));
  }

  @override
  Future<WaterRule> createDraftRule({
    required String siteId,
    required String tempek,
    required double allocationShare,
    required String scheduleLabel,
    required String parumanReference,
    required DateTime effectiveFrom,
    required DateTime effectiveTo,
  }) async {
    if (_user?.role != UserRole.pekaseh) {
      throw const SubakoException(
        'Hanya Pekaseh yang boleh membuat draf aturan air.',
      );
    }
    final WaterRule rule = WaterRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      siteId: siteId,
      tempek: tempek,
      version: 1,
      status: RuleStatus.draft,
      allocationShare: allocationShare,
      scheduleLabel: scheduleLabel,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      parumanReference: parumanReference,
      updatedAt: DateTime.now().toUtc(),
    );
    _rules.add(rule);
    _rulesController.add(List<WaterRule>.unmodifiable(_rules));
    return rule;
  }

  @override
  Future<WaterRule> submitRule(String ruleId) =>
      _changeRule(ruleId, RuleStatus.submitted);

  @override
  Future<WaterRule> approveAndPublishRule(String ruleId) async {
    if (_user?.role != UserRole.pekaseh) {
      throw const SubakoException(
        'Persetujuan aturan hanya boleh dilakukan Pekaseh berwenang.',
      );
    }
    return _changeRule(ruleId, RuleStatus.published);
  }

  Future<WaterRule> _changeRule(String ruleId, RuleStatus status) async {
    final int index = _rules.indexWhere((WaterRule r) => r.id == ruleId);
    if (index < 0) {
      throw const SubakoException('Aturan tidak ditemukan.');
    }
    final WaterRule existing = _rules[index];
    final WaterRule updated = WaterRule(
      id: existing.id,
      siteId: existing.siteId,
      tempek: existing.tempek,
      version: status == RuleStatus.published
          ? existing.version + 0
          : existing.version,
      status: status,
      allocationShare: existing.allocationShare,
      scheduleLabel: existing.scheduleLabel,
      effectiveFrom: existing.effectiveFrom,
      effectiveTo: existing.effectiveTo,
      parumanReference: existing.parumanReference,
      updatedAt: DateTime.now().toUtc(),
    );
    _rules[index] = updated;
    _rulesController.add(List<WaterRule>.unmodifiable(_rules));
    return updated;
  }

  @override
  Future<bool> verifyLedger(String siteId) async =>
      LedgerHash.verify(_ledger.reversed.toList()).valid;

  void dispose() {
    _timer?.cancel();
    _authController.close();
    _devicesController.close();
    _alertsController.close();
    _rulesController.close();
    _commandsController.close();
    _ledgerController.close();
  }
}
