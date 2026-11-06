import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'firebase_repository.dart';

Future<FirebaseRepository> bootstrapFirebase() async {
  const String apiKey = String.fromEnvironment('SUBAKO_FIREBASE_API_KEY');
  const String appId = String.fromEnvironment('SUBAKO_FIREBASE_APP_ID');
  const String senderId = String.fromEnvironment(
    'SUBAKO_FIREBASE_MESSAGING_SENDER_ID',
  );
  if (AppConfig.firebaseProjectId.isEmpty ||
      apiKey.isEmpty ||
      appId.isEmpty ||
      senderId.isEmpty) {
    throw StateError(
      'Konfigurasi Firebase belum lengkap. Gunakan --dart-define-from-file dengan konfigurasi project development.',
    );
  }
  if (AppConfig.useEmulators &&
      !AppConfig.firebaseProjectId.startsWith('demo-')) {
    throw StateError(
      'Emulator memerlukan project ID demo- agar tidak mengakses project online.',
    );
  }
  if (kReleaseMode && (AppConfig.appCheckDebug || AppConfig.useEmulators)) {
    throw StateError(
      'Debug App Check dan emulator tidak diizinkan dalam release.',
    );
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: AppConfig.firebaseProjectId,
      authDomain: String.fromEnvironment('SUBAKO_FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('SUBAKO_FIREBASE_STORAGE_BUCKET'),
    ),
  );
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: AppConfig.functionsRegion,
  );
  if (AppConfig.useEmulators) {
    final String host =
        const String.fromEnvironment('SUBAKO_EMULATOR_HOST').isNotEmpty
        ? const String.fromEnvironment('SUBAKO_EMULATOR_HOST')
        : kIsWeb
        ? '127.0.0.1'
        : '10.0.2.2';
    await auth.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8085);
    functions.useFunctionsEmulator(host, 5001);
    firestore.settings = const Settings(persistenceEnabled: false);
  } else if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AppConfig.appCheckDebug && kDebugMode
          ? const AndroidDebugProvider(
              debugToken: String.fromEnvironment('SUBAKO_APPCHECK_DEBUG_TOKEN'),
            )
          : const AndroidPlayIntegrityProvider(),
    );
  } else if (AppConfig.geminiEnabled) {
    throw StateError(
      'Gemini online pada build ini hanya dikonfigurasi untuk Android dengan App Check.',
    );
  }
  return FirebaseRepository(
    firestore: firestore,
    auth: auth,
    cloudFunctions: functions,
  );
}
