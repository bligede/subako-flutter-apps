import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'services/firebase_bootstrap.dart';
import 'services/firebase_ai_assistant_service.dart';
import 'shared/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  if (!AppConfig.firebaseEnabled) {
    runApp(const ProviderScope(child: SubakoApp()));
    return;
  }
  try {
    final repository = await bootstrapFirebase();
    runApp(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          aiAssistantProvider.overrideWithValue(
            FirebaseAiAssistantService(repository: repository),
          ),
        ],
        child: const SubakoApp(),
      ),
    );
  } on Object {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.cloud_off, size: 48),
                  SizedBox(height: 20),
                  Text(
                    'Firebase belum siap',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Periksa koneksi, konfigurasi project dan App Check. '
                    'Baca panduan setup Firebase. Untuk demo lokal gunakan build SIMULATION.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
