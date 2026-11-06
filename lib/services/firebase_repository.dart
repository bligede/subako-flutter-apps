import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../core/domain/freshness.dart';
import '../core/config/app_config.dart';
import '../shared/models/enums.dart';
import '../shared/models/models.dart';
import 'subako_repository.dart';

/// Implementasi Firebase (Auth + Firestore + callable Functions).
///
/// Semua penulisan authoritative dilakukan Cloud Functions; klien hanya
/// membaca dan meminta aksi.
class FirebaseRepository implements SubakoRepository {
  FirebaseRepository({
    required this.firestore,
    required this.auth,
    this.cloudFunctions,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseFunctions? cloudFunctions;
  UserProfile? _profile;

  @override
  UserProfile? get currentUser {
    return auth.currentUser == null ? null : _profile;
  }

  Future<UserProfile> _loadProfile(User user) async {
    final doc = await firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null || data['active'] == false) {
      throw const SubakoException(
        'Akun belum diberi akses SUBAKO atau telah dinonaktifkan.',
      );
    }
    final base = UserProfile.fromMap(user.uid, data);
    final Map<String, SiteMembership> memberships = {};
    for (final siteId in base.siteIds.take(30)) {
      final member =
          (await firestore.doc('sites/$siteId/members/${user.uid}').get())
              .data();
      if (member?['active'] != true) continue;
      memberships[siteId] = SiteMembership(
        role: UserRole.fromWire(member!['role'] as String?),
        permissions: (member['permissions'] as List<dynamic>? ?? [])
            .cast<String>()
            .toSet(),
      );
    }
    return UserProfile(
      uid: user.uid,
      name: base.name,
      email: user.email ?? base.email,
      role: memberships.values.firstOrNull?.role ?? UserRole.farmerViewer,
      siteIds: memberships.keys.toList(),
      memberships: memberships,
      grantedPermissions: const <String>{},
    );
  }

  @override
  Stream<UserProfile?> authStateChanges() {
    return Stream.multi((controller) {
      int generation = 0;
      Future<void> refresh() async {
        final int request = ++generation;
        final User? user = auth.currentUser;
        try {
          final profile = user == null ? null : await _loadProfile(user);
          if (request != generation || controller.isClosed) return;
          _profile = profile;
          controller.add(profile);
        } on Object catch (error, stack) {
          if (request != generation || controller.isClosed) return;
          _profile = null;
          controller.addError(error, stack);
        }
      }

      final subscription = auth.idTokenChanges().listen((_) => refresh());
      final timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => refresh(),
      );
      controller.onCancel = () {
        generation++;
        timer.cancel();
        subscription.cancel();
      };
    });
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        throw const SubakoException('Login gagal: sesi tidak terbentuk.');
      }
      _profile = await _loadProfile(user);
      return _profile!;
    } on FirebaseAuthException catch (error) {
      throw SubakoException(authMessage(error.code), code: error.code);
    }
  }

  String authMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email atau kata sandi tidak sesuai.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi administrator.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Jaringan tidak tersedia. Periksa koneksi Anda.';
      default:
        return 'Login gagal ($code).';
    }
  }

  @override
  Future<void> signOut() async {
    _profile = null;
    await auth.signOut();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  @override
  Stream<List<Site>> watchSites() {
    final List<String> siteIds = _profile?.siteIds ?? [];
    if (siteIds.isEmpty) return Stream.value(const <Site>[]);
    return firestore
        .collection('sites')
        .where(FieldPath.documentId, whereIn: siteIds.take(30).toList())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data =
                    doc.data() ?? <String, dynamic>{};
                return Site(
                  id: doc.id,
                  name: (data['name'] as String?) ?? doc.id,
                  village: (data['village'] as String?) ?? '',
                  regency: (data['regency'] as String?) ?? '',
                  tempekCount: (data['tempekCount'] as num?)?.toInt() ?? 0,
                  gateCount: (data['gateCount'] as num?)?.toInt() ?? 0,
                  dataState: DataState.fromWire(data['dataState'] as String?),
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Stream<List<Device>> watchDevices(String siteId) {
    return firestore
        .collection('devices')
        .where('siteId', isEqualTo: siteId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          return snapshot.docs.map(_deviceFromDoc).toList(growable: false);
        });
  }

  Device _deviceFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Timestamp? seen = data['lastSeen'] as Timestamp?;
    final DateTime lastSeen =
        seen?.toDate().toUtc() ??
        DateTime.now().toUtc().subtract(const Duration(days: 1));
    return Device(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      siteId: (data['siteId'] as String?) ?? '',
      kind: DeviceKind.fromWire(data['kind'] as String?),
      mode: GateMode.fromWire(data['mode'] as String?),
      dataState: Freshness.evaluate(
        lastSeen,
        simulated: data['source'] == 'SIMULATION',
      ),
      lastSeen: lastSeen,
      positionPercent: (data['positionPercent'] as num?)?.toDouble(),
      batteryPercent: (data['batteryPercent'] as num?)?.toDouble(),
      rssi: (data['rssi'] as num?)?.toInt(),
      firmware: data['firmware'] as String?,
      motorCurrentAmp: (data['motorCurrentAmp'] as num?)?.toDouble(),
      upperLimit: data['upperLimit'] as bool?,
      lowerLimit: data['lowerLimit'] as bool?,
      fromCache: doc.metadata.isFromCache,
      simulated: data['source'] == 'SIMULATION',
    );
  }

  @override
  Stream<TelemetrySnapshot> watchTelemetry(String deviceId) {
    return firestore
        .collection('telemetryLatest')
        .doc(deviceId)
        .snapshots(includeMetadataChanges: true)
        .map((DocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
          final Timestamp? ts = data['recordedAt'] as Timestamp?;
          final values = ['upstreamCm', 'downstreamCm', 'flowLiterPerSecond'];
          if (!doc.exists ||
              ts == null ||
              !['OK', 'SUSPECT'].contains(data['quality']) ||
              values.any(
                (key) => data[key] is! num || !(data[key] as num).isFinite,
              )) {
            throw const SubakoException(
              'Telemetry belum tersedia atau kualitas sensor tidak valid. Tidak ada nilai pengganti.',
            );
          }
          final DateTime recordedAt = ts.toDate().toUtc();
          return TelemetrySnapshot(
            deviceId: deviceId,
            upstreamCm: (data['upstreamCm'] as num?)?.toDouble() ?? 0,
            downstreamCm: (data['downstreamCm'] as num?)?.toDouble() ?? 0,
            flowLiterPerSecond:
                (data['flowLiterPerSecond'] as num?)?.toDouble() ?? 0,
            recordedAt: recordedAt,
            dataState: Freshness.evaluate(
              recordedAt,
              simulated: data['source'] == 'SIMULATION',
            ),
            quality: (data['quality'] as String?) ?? 'Tidak diketahui',
            fromCache: doc.metadata.isFromCache,
            simulated: data['source'] == 'SIMULATION',
          );
        });
  }

  @override
  Stream<List<Alert>> watchAlerts(String siteId) {
    return firestore
        .collection('alerts')
        .where('siteId', isEqualTo: siteId)
        .orderBy('raisedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data =
                    doc.data() ?? <String, dynamic>{};
                return Alert(
                  id: doc.id,
                  siteId: data['siteId'] as String? ?? '',
                  deviceId: data['deviceId'] as String? ?? '',
                  severity: AlertSeverity.fromWire(data['severity'] as String?),
                  title: data['title'] as String? ?? '',
                  evidence: data['evidence'] as String? ?? '',
                  suggestedAction: data['suggestedAction'] as String? ?? '',
                  raisedAt:
                      (data['raisedAt'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                  acknowledged: data['acknowledged'] as bool? ?? false,
                  acknowledgedBy: data['acknowledgedBy'] as String?,
                  acknowledgedAt: (data['acknowledgedAt'] as Timestamp?)
                      ?.toDate()
                      .toUtc(),
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Stream<List<WaterRule>> watchRules(String siteId) {
    return firestore
        .collection('waterRules')
        .where('siteId', isEqualTo: siteId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data =
                    doc.data() ?? <String, dynamic>{};
                return WaterRule(
                  id: doc.id,
                  siteId: data['siteId'] as String? ?? '',
                  tempek: data['tempek'] as String? ?? '',
                  version: (data['version'] as num?)?.toInt() ?? 1,
                  status: RuleStatus.fromWire(data['status'] as String?),
                  allocationShare:
                      (data['allocationShare'] as num?)?.toDouble() ?? 0,
                  scheduleLabel: data['scheduleLabel'] as String? ?? '',
                  effectiveFrom:
                      (data['effectiveFrom'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                  effectiveTo:
                      (data['effectiveTo'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                  parumanReference: data['parumanReference'] as String? ?? '',
                  updatedAt:
                      (data['updatedAt'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Stream<List<LedgerEntry>> watchLedger(String siteId) {
    return firestore
        .collection('waterLedger')
        .where('siteId', isEqualTo: siteId)
        .orderBy('recordedAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data =
                    doc.data() ?? <String, dynamic>{};
                return LedgerEntry(
                  id: doc.id,
                  siteId: data['siteId'] as String? ?? '',
                  tempek: data['tempek'] as String? ?? '',
                  gateId: data['gateId'] as String? ?? '',
                  ruleId: data['ruleId'] as String? ?? '',
                  ruleVersion: (data['ruleVersion'] as num?)?.toInt() ?? 1,
                  recordedAt:
                      (data['recordedAt'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                  volumeCubicMeter:
                      (data['volumeCubicMeter'] as num?)?.toDouble() ?? 0,
                  actor: data['actor'] as String? ?? '',
                  source: data['source'] as String? ?? '',
                  prevHash: data['prevHash'] as String? ?? '',
                  hash: data['hash'] as String? ?? '',
                  correctionOf: data['correctionOf'] as String?,
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Stream<List<GateCommand>> watchCommands(String siteId) {
    return firestore
        .collection('commands')
        .where('siteId', isEqualTo: siteId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                final Map<String, dynamic> data =
                    doc.data() ?? <String, dynamic>{};
                return GateCommand(
                  id: doc.id,
                  gateId: data['gateId'] as String? ?? '',
                  siteId: data['siteId'] as String? ?? '',
                  action: data['action'] as String? ?? '',
                  targetPositionPercent:
                      (data['targetPositionPercent'] as num?)?.toDouble() ?? 0,
                  status: CommandStatus.fromWire(data['status'] as String?),
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate().toUtc() ??
                      DateTime.now().toUtc(),
                  actorUid: data['actorUid'] as String? ?? '',
                  ruleId: data['ruleId'] as String? ?? '',
                  reason: data['reason'] as String? ?? '',
                  expiresAt: (data['expiresAt'] as Timestamp?)
                      ?.toDate()
                      .toUtc(),
                  updatedAt: (data['updatedAt'] as Timestamp?)
                      ?.toDate()
                      .toUtc(),
                  failureReason: data['failureReason'] as String?,
                );
              })
              .toList(growable: false);
        });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    if (!AppConfig.trustedFunctionsEnabled && !AppConfig.useEmulators) {
      throw const SubakoException(
        'Workflow server belum di-deploy pada project development ini. Gunakan build demo untuk mencoba alur simulasi.',
      );
    }
    final FirebaseFunctions? functions = cloudFunctions;
    if (functions == null) {
      throw const SubakoException('Cloud Functions belum dikonfigurasi.');
    }
    final HttpsCallableResult<dynamic> result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call(payload);
    final dynamic data = result.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchAiContext(String siteId) async {
    if (AppConfig.trustedFunctionsEnabled || AppConfig.useEmulators) {
      return _call('getAiContext', {'siteId': siteId});
    }
    // Spark development: authenticated, server reads scoped by deployed Rules.
    final User? user = auth.currentUser;
    if (user == null) {
      throw const SubakoException('Masuk kembali untuk bertanya.');
    }
    final profile = await _loadProfile(user);
    if (!profile.siteIds.contains(siteId)) {
      throw const SubakoException('Site tidak dapat diakses.');
    }
    const options = GetOptions(source: Source.server);
    final site = (await firestore.doc('sites/$siteId').get(options)).data();
    final devices = await firestore
        .collection('devices')
        .where('siteId', isEqualTo: siteId)
        .limit(15)
        .get(options);
    final List<Map<String, dynamic>> readings = [];
    for (final device in devices.docs) {
      final latest =
          (await firestore.doc('telemetryLatest/${device.id}').get(options))
              .data();
      final DateTime? at = (latest?['recordedAt'] as Timestamp?)
          ?.toDate()
          .toUtc();
      readings.add({
        'deviceId': device.id,
        'name': device.data()['name'],
        'mode': device.data()['mode'],
        'recordedAt': at?.toIso8601String(),
        'dataState': at == null
            ? 'OFFLINE'
            : Freshness.evaluate(
                at,
                simulated: latest?['source'] == 'SIMULATION',
              ).label,
        'quality': latest?['quality'] ?? 'MISSING',
        'upstreamCm': latest?['upstreamCm'],
        'downstreamCm': latest?['downstreamCm'],
        'flowLiterPerSecond': latest?['flowLiterPerSecond'],
      });
    }
    final rules = await firestore
        .collection('waterRules')
        .where('siteId', isEqualTo: siteId)
        .where('status', isEqualTo: 'PUBLISHED')
        .limit(5)
        .get(options);
    final now = DateTime.now().toUtc();
    final active = rules.docs
        .where((d) {
          final start = (d.data()['effectiveFrom'] as Timestamp?)?.toDate();
          final end = (d.data()['effectiveTo'] as Timestamp?)?.toDate();
          return start != null &&
              end != null &&
              !start.isAfter(now) &&
              end.isAfter(now);
        })
        .map(
          (d) => {
            'id': d.id,
            'version': d.data()['version'],
            'schedule': d.data()['scheduleLabel'],
            'parumanReference': d.data()['parumanReference'],
          },
        )
        .toList();
    final alerts = await firestore
        .collection('alerts')
        .where('siteId', isEqualTo: siteId)
        .where('acknowledged', isEqualTo: false)
        .limit(10)
        .get(options);
    return {
      'siteId': siteId,
      'siteName': site?['name'] ?? siteId,
      'capturedAt': now.toIso8601String(),
      'source': 'FIRESTORE_SECURITY_RULES_SCOPED',
      'readings': readings,
      'activeRules': active,
      'alerts': alerts.docs
          .map(
            (d) => {
              'id': d.id,
              'title': d.data()['title'],
              'severity': d.data()['severity'],
            },
          )
          .toList(),
    };
  }

  @override
  Future<GateCommand> requestGateCommand({
    required String gateId,
    required String siteId,
    required double targetPositionPercent,
    required String reason,
  }) async {
    final Map<String, dynamic> data = await _call('createGateCommand', {
      'gateId': gateId,
      'siteId': siteId,
      'targetPositionPercent': targetPositionPercent,
      'reason': reason,
      'clientRequestId': DateTime.now().microsecondsSinceEpoch.toString(),
    });
    return GateCommand(
      id: data['commandId'] as String? ?? '',
      gateId: gateId,
      siteId: siteId,
      action: 'SET_POSITION',
      targetPositionPercent: targetPositionPercent,
      status: CommandStatus.fromWire(data['status'] as String?),
      createdAt: DateTime.now().toUtc(),
      actorUid: auth.currentUser?.uid ?? '',
      ruleId: data['ruleId'] as String? ?? '',
      reason: reason,
    );
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    await _call('acknowledgeAlert', <String, dynamic>{'alertId': alertId});
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
    await _call('createWaterRuleDraft', <String, dynamic>{
      'siteId': siteId,
      'tempek': tempek,
      'allocationShare': allocationShare,
      'scheduleLabel': scheduleLabel,
      'parumanReference': parumanReference,
      'effectiveFrom': effectiveFrom.toUtc().toIso8601String(),
      'effectiveTo': effectiveTo.toUtc().toIso8601String(),
    });
    return (await watchRules(siteId).first).first;
  }

  @override
  Future<WaterRule> submitRule(String ruleId) async {
    await _call('submitWaterRule', <String, dynamic>{'ruleId': ruleId});
    throw const SubakoException(
      'Aturan dikirim. Muat ulang daftar untuk melihat status terbaru.',
    );
  }

  @override
  Future<WaterRule> approveAndPublishRule(String ruleId) async {
    await _call('approveWaterRule', <String, dynamic>{'ruleId': ruleId});
    throw const SubakoException(
      'Aturan disetujui. Muat ulang daftar untuk melihat versi terbit.',
    );
  }

  @override
  Future<bool> verifyLedger(String siteId) async {
    final Map<String, dynamic> data = await _call('verifyLedger', {
      'siteId': siteId,
    });
    return data['valid'] as bool? ?? false;
  }

  /// Inisialisasi Firebase; hanya dipanggil bila AppConfig.firebaseEnabled.
  static Future<void> initialize({FirebaseOptions? options}) async {
    await Firebase.initializeApp(options: options);
    debugPrint('Firebase terinisialisasi.');
  }
}
