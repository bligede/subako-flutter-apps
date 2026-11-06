import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../core/domain/freshness.dart';
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

  @override
  UserProfile? get currentUser {
    final User? user = auth.currentUser;
    if (user == null) {
      return null;
    }
    // Profil lengkap dimuat dari dokumen users/{uid}; fallback minimal.
    return UserProfile(
      uid: user.uid,
      name: user.displayName ?? user.email ?? 'Pengguna SUBAKO',
      email: user.email ?? '',
      role: UserRole.farmerViewer,
      siteIds: const <String>[],
    );
  }

  @override
  Stream<UserProfile?> authStateChanges() {
    return auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        return null;
      }
      final DocumentSnapshot<Map<String, dynamic>> doc = await firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        return currentUser;
      }
      return UserProfile.fromMap(user.uid, doc.data() ?? <String, dynamic>{});
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
      final DocumentSnapshot<Map<String, dynamic>> doc = await firestore
          .collection('users')
          .doc(user.uid)
          .get();
      return UserProfile.fromMap(
        user.uid,
        doc.data() ?? <String, dynamic>{'email': email},
      );
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
  Future<void> signOut() => auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  @override
  Stream<List<Site>> watchSites() {
    return firestore.collection('sites').snapshots().map((snapshot) {
      return snapshot.docs
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
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
        .snapshots()
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
    );
  }

  @override
  Stream<TelemetrySnapshot> watchTelemetry(String deviceId) {
    return firestore
        .collection('telemetryLatest')
        .doc(deviceId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
          final Timestamp? ts = data['recordedAt'] as Timestamp?;
          final DateTime recordedAt =
              ts?.toDate().toUtc() ?? DateTime.now().toUtc();
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
    final FirebaseFunctions? functions = cloudFunctions;
    if (functions == null) {
      throw const SubakoException('Cloud Functions belum dikonfigurasi.');
    }
    final HttpsCallableResult<dynamic> result = await functions
        .httpsCallable(name)
        .call(payload);
    final dynamic data = result.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
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
