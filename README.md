# SUBAKO — Smart Irrigation Management Platform (Android v0.2.1)

Aplikasi Android untuk pengelolaan air Subak: pemantauan level/debit, status
pintu, aturan alokasi, Buku Catatan Air, alert, laporan, dan asisten AI.

**by Mikiko Technology** · _Tradisi memutuskan. Teknologi mengukur. SUBAKO mengeksekusi._

- Framework: Flutter + Dart (Material 3, Riverpod, go_router)
- Backend kanonik: Firebase (Auth, Firestore, Functions 2nd gen, AI Logic)
- IoT: LoRaWAN/ChirpStack v4 melalui Cloud Run IoT bridge
- Bahasa UI: Bahasa Indonesia · Zona waktu: WITA (UTC+8)

Implementasi Flutter ini merupakan opsi aplikasi terpisah dari Web-PWA. Panduan terbaru: [DEVELOPMENT-SETUP](docs/DEVELOPMENT-SETUP.md), [catatan rilis](docs/RELEASE-NOTES-0.2.1.md), dan [rencana kelanjutan](docs/IMPLEMENTATION-PLAN-2026-11-06.md). Gunakan Flutter **3.47.9 / Dart 3.13.7**.

## Status build ini

| Area | Status |
|---|---|
| Fondasi Flutter, tema, routing, role-aware nav | Selesai |
| Dashboard, monitoring, gate + command lifecycle | Selesai (data simulasi) |
| Aturan air + siklus DRAFT→PUBLISHED | Selesai (demo repository) |
| Buku Catatan Air + verifikasi rantai hash | Selesai |
| Alert, laporan + ekspor CSV | Selesai |
| AI assistant | Demo deterministik terpisah; adapter `firebase_ai` + konteks berotorisasi tersedia. Hasil koneksi cloud pada laporan verifikasi |
| Firestore rules + indexes | Emulator tests; Rules/indeks development dipasang pada project khusus SUBAKO |
| Cloud Functions | Emulator workflow tests; **belum di-deploy online**, mutation cloud default nonaktif |
| Cloud Run IoT bridge | Ditulis + typecheck; **belum di-deploy** |
| FCM, App Check produksi, peta, PDF | Belum diimplementasikan |
| Project Firebase | `subako-dev-mikiko`; Email/Password Auth dan Firestore Jakarta, data SIMULATION |

> Build default adalah **mode simulasi**: setiap angka diberi label
> `SIMULATION`. Tidak ada data lapangan dan tidak ada perintah yang mencapai
> perangkat fisik.

## Menjalankan (mode demo, tanpa Firebase)

```bash
flutter pub get
flutter run --flavor demo --dart-define=SUBAKO_FIREBASE_ENABLED=false
```

Akun demo (sandi `Subako#2026`):

| Email | Peran |
|---|---|
| `petani@subako.demo` | farmer_viewer |
| `operator@subako.demo` | operator |
| `pekaseh@subako.demo` | pekaseh |
| `admin@subako.demo` | mikiko_admin |

## Menjalankan dengan Firebase

Ikuti [panduan development terbaru](docs/DEVELOPMENT-SETUP.md). Flavor `development` memakai `.local/firebase-development.json` yang diabaikan Git, dengan akun online bersandi acak terpisah dari demo. Jangan menaruh API key Gemini, App Check debug token atau service account di repo. Cloud Functions memerlukan setup deployment/billing tersendiri; proyek ini tidak otomatis dihubungkan ke akun billing.

## Struktur

```text
lib/
  core/        config, tema, routing, RBAC, domain (command, ledger, freshness)
  shared/      model, widget, provider Riverpod
  services/    repository demo + Firebase, AI assistant
  features/    splash, onboarding, auth, dashboard, monitoring, gate,
               aturan air, ledger, alert, laporan, AI, profil
functions/     Cloud Functions (TypeScript)
cloud-run/     IoT bridge (TypeScript)
firestore.rules, firestore.indexes.json, firebase.json, .firebaserc
docs/          arsitektur, data model, rules, RBAC, kontrak IoT, Gemini, deploy
test/          unit + widget test
```

## Verifikasi yang dijalankan

```bash
dart format --output=none --set-exit-if-changed lib test   # bersih
flutter analyze                                            # No issues found!
flutter test                                               # 30/30 lulus
npm run test:rules                                         # 10/10 lulus (emulator)
npm run test:backend                                       # 5/5 lulus (emulator)
npm --prefix functions run build                           # lulus
npm --prefix cloud-run/iot-bridge run typecheck              # lulus
```

Build APK memerlukan JDK + Android SDK; lihat [docs/deployment.md](docs/deployment.md).

Hasil aktual, hash APK dan batas verifikasi cloud ada pada [laporan verifikasi 0.2.1](docs/VERIFICATION-0.2.1.md). Kedua APK debug berhasil dibangun dan diverifikasi tanda tangannya; belum ada uji pemasangan pada ponsel nyata. Auth/Firestore online lulus, sedangkan generasi Gemini masih timeout. Untuk mengulang backend jalankan `npm ci` dan `npm --prefix functions ci` terlebih dahulu (JDK 21, Node 24). Build APK: `flutter build apk --debug --flavor demo --dart-define=SUBAKO_FIREBASE_ENABLED=false`.

## Batasan keselamatan

- Aplikasi bukan lapisan keselamatan fisik. MANUAL, E-STOP, dan interlock lokal
  selalu berwenang.
- Tidak ada antrean command offline dan tidak ada retry otomatis.
- `ACKNOWLEDGED` tidak sama dengan `EXECUTED`.
- Asisten AI bersifat advisory dan tidak dapat mengubah aturan atau menggerakkan
  pintu.
- Ledger memakai rantai hash (bukan blockchain).

## Dokumentasi

- [Penilaian repositori](docs/repository-assessment.md)
- [Arsitektur](docs/architecture.md)
- [Model data Firestore](docs/firestore-data-model.md)
- [Security rules](docs/security-rules.md)
- [Matriks RBAC](docs/rbac-matrix.md)
- [Kontrak IoT](docs/iot-contract.md)
- [Gemini assistant](docs/gemini-assistant.md)
- [Deployment](docs/deployment.md)
