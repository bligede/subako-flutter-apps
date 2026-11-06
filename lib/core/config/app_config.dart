/// Konfigurasi global SUBAKO.
///
/// Nilai Firebase dibaca dari `--dart-define` agar build demo (tanpa project
/// Firebase) dan build staging/production memakai kode yang sama.
class AppConfig {
  const AppConfig._();

  static const String appName = 'SUBAKO';
  static const String vendor = 'Mikiko Technology';
  static const String tagline = 'Smart Irrigation Management Platform';
  static const String appVersion = '0.2.2';
  static const String buildLabel = 'v0.2.2 (4)';
  static const String timezoneOffsetLabel = 'WITA';

  /// Firebase hanya diaktifkan bila project benar-benar dikonfigurasi.
  ///
  /// Demo build: `--dart-define=SUBAKO_FIREBASE_ENABLED=false` (default).
  /// Firebase build: `--dart-define=SUBAKO_FIREBASE_ENABLED=true` beserta
  /// `firebase_options.dart` hasil FlutterFire CLI.
  static const bool firebaseEnabled = bool.fromEnvironment(
    'SUBAKO_FIREBASE_ENABLED',
    defaultValue: false,
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'SUBAKO_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const bool useEmulators = bool.fromEnvironment('SUBAKO_EMULATORS');
  static const bool appCheckDebug = bool.fromEnvironment(
    'SUBAKO_APPCHECK_DEBUG',
  );
  static const bool geminiEnabled = bool.fromEnvironment(
    'SUBAKO_GEMINI_ENABLED',
  );
  static const bool trustedFunctionsEnabled = bool.fromEnvironment(
    'SUBAKO_TRUSTED_FUNCTIONS',
  );
  static const String functionsRegion = String.fromEnvironment(
    'SUBAKO_FUNCTIONS_REGION',
    defaultValue: 'asia-southeast2',
  );

  /// Model Gemini dipilih terpusat; jangan disebar sebagai literal di UI.
  static const String geminiModel = String.fromEnvironment(
    'SUBAKO_GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  static const Duration liveThreshold = Duration(minutes: 5);
  static const Duration staleThreshold = Duration(hours: 6);

  /// Batas panjang prompt/response agar biaya dan penyalahgunaan terkendali.
  static const int maxPromptChars = 2000;
  static const int maxResponseChars = 6000;

  static const String aiDisclaimer =
      'Jawaban AI bersifat informatif dan bukan keputusan resmi Pekaseh '
      'atau instruksi keselamatan.';
}
