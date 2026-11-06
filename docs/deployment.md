# Deployment & Konfigurasi

## 1. Prasyarat

- Flutter 3.47.x (Dart 3.13.x), Android SDK + JDK 17 untuk build APK.
- Firebase CLI, Node.js 20 untuk Functions/Cloud Run.
- Project Firebase milik Mikiko Technology (dev/staging/production terpisah).

## 2. Firebase setup (wajib sebelum build produksi)

1. Buat project Firebase + Google Cloud yang tertaut.
2. Daftarkan aplikasi Android `id.mikiko.subako` (lihat `android/app/build.gradle.kts`).
3. Aktifkan Authentication (email/password; provider lain sesuai keputusan PO).
4. Buat Firestore (region `asia-southeast2`), deploy rules + indexes:
   `firebase deploy --only firestore:rules,firestore:indexes`.
5. Aktifkan Cloud Functions 2nd gen dan API yang dibutuhkan.
6. Aktifkan App Check (Play Integrity); token debug hanya untuk lokal.
7. Aktifkan Firebase AI Logic dan pilih provider Gemini yang disetujui.
8. Aktifkan FCM, Crashlytics, Performance, Remote Config, budget alert.

## 3. Menjalankan aplikasi

Demo (tanpa Firebase, data SIMULATION):

```bash
flutter pub get
flutter run --dart-define=SUBAKO_FIREBASE_ENABLED=false
```

Firebase:

```bash
flutter run \
  --dart-define=SUBAKO_FIREBASE_ENABLED=true \
  --dart-define=SUBAKO_FIREBASE_PROJECT_ID=<project> \
  --dart-define=SUBAKO_FIREBASE_API_KEY=<key> \
  --dart-define=SUBAKO_FIREBASE_APP_ID=<appId> \
  --dart-define=SUBAKO_FIREBASE_MESSAGING_SENDER_ID=<senderId> \
  --dart-define=SUBAKO_FIREBASE_STORAGE_BUCKET=<bucket>
```

Alternatif: jalankan `flutterfire configure` lalu ganti bootstrap di
`lib/main.dart` dengan `DefaultFirebaseOptions.currentPlatform`. Jangan
commit service account atau kunci penandatanganan.

## 4. Build APK/AAB

```bash
flutter build apk --debug
flutter build appbundle --release --flavor production
```

Build release memerlukan keystore (simpan di secret store, bukan repo) dan
`android/key.properties` yang di-gitignore.

## 5. Functions

```bash
cd functions && npm ci && npm run build
firebase deploy --only functions
```

Secret (contoh): `firebase functions:secrets:set CHIRPSTACK_API_TOKEN`.

## 6. Cloud Run IoT bridge

```bash
cd cloud-run/iot-bridge && npm ci && npm run build
gcloud run deploy subako-iot-bridge --source . \
  --region asia-southeast2 --no-allow-unauthenticated
```

Env: `BRIDGE_SHARED_SECRET` (Secret Manager), `GOOGLE_APPLICATION_CREDENTIALS`
lewat service account Cloud Run (jangan file JSON di repo).

## 7. CI

`.github/workflows/ci.yml` menjalankan format, analyze, test, serta typecheck
Functions dan bridge. Build APK di CI memerlukan konfigurasi Android SDK;
tambahkan job terpisah saat pipeline rilis disiapkan.
