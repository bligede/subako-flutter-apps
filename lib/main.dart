import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'services/firebase_repository.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  if (AppConfig.firebaseEnabled) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: const String.fromEnvironment('SUBAKO_FIREBASE_API_KEY'),
        appId: const String.fromEnvironment('SUBAKO_FIREBASE_APP_ID'),
        messagingSenderId: const String.fromEnvironment(
          'SUBAKO_FIREBASE_MESSAGING_SENDER_ID',
        ),
        projectId: AppConfig.firebaseProjectId,
        storageBucket: const String.fromEnvironment(
          'SUBAKO_FIREBASE_STORAGE_BUCKET',
        ),
      ),
    );

    // App Check wajib untuk Firebase AI Logic pada build non-debug.
    try {
      await FirebaseAppCheck.instance.activate();
    } on Object catch (error) {
      debugPrint('App Check gagal diaktifkan: $error');
    }

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    setBootstrapRepository(
      FirebaseRepository(
        firestore: FirebaseFirestore.instance,
        auth: FirebaseAuth.instance,
        cloudFunctions: FirebaseFunctions.instance,
      ),
    );
  }

  runApp(const ProviderScope(child: SubakoApp()));
}
