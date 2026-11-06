# SUBAKO — Smart Irrigation Management Platform (Android v0.2)

Aplikasi Android untuk pengelolaan air Subak: pemantauan level/debit, status
pintu, aturan alokasi, Buku Catatan Air, alert, laporan, dan asisten AI.

**by Mikiko Technology** · _Tradisi memutuskan. Teknologi mengukur. SUBAKO mengeksekusi._

- Framework: Flutter + Dart (Material 3, Riverpod, go_router)
- Backend kanonik: Firebase (Auth, Firestore, Functions 2nd gen, AI Logic)
- IoT: LoRaWAN/ChirpStack v4 melalui Cloud Run IoT bridge
- Bahasa UI: Bahasa Indonesia · Zona waktu: WITA (UTC+8)

## Status build ini

| Area | Status |
|---|---|
| Fondasi Flutter, tema, routing, role-aware nav | Selesai |
| Dashboard, monitoring, gate + command lifecycle | Selesai (data simulasi) |
| Aturan air + siklus DRAFT→PUBLISHED | Selesai (demo repository) |
| Buku Catatan Air + verifikasi rantai hash | Selesai |
| Alert, laporan + ekspor CSV | Selesai |
| AI assistant | Demo deterministik; adapter Firebase AI Logic belum diaktifkan |
| Firestore rules + indexes | Ditulis, **belum diuji di emulator** |
| Cloud Functions | Ditulis + typecheck; **belum di-deploy** |
| Cloud Run IoT bridge | Ditulis + typecheck; **belum di-deploy** |
| FCM, App Check produksi, peta, PDF | Belum diimplementasikan |
| Project Firebase | Belum dibuat/dikonfigurasi (butuh akses Console) |

> Build default adalah **mode simulasi**: setiap angka diberi label
> `SIMULATION`. Tidak ada data lapangan dan tidak ada perintah yang mencapai
> perangkat fisik.

## Menjalankan (mode demo, tanpa Firebase)

```bash
flutter pub get
flutter run --dart-define=SUBAKO_FIREBASE_ENABLED=false
```

Akun demo (sandi `Subako#2026`):

| Email | Peran |
|---|---|
| `petani@subako.demo` | farmer_viewer |
| `operator@subako.demo` | operator |
| `pekaseh@subako.demo` | pekaseh |
| `admin@subako.demo` | mikiko_admin |

## Menjalankan dengan Firebase

Lihat [docs/deployment.md](docs/deployment.md). Ringkasnya: daftarkan aplikasi
Android, aktifkan Auth/Firestore/Functions/App Check/AI Logic, deploy rules,
lalu build dengan `--dart-define=SUBAKO_FIREBASE_ENABLED=true` dan kredensial
project. **Jangan** menaruh API key Gemini atau service account di repo.

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
flutter test                                               # 23/23 lulus
cd functions && npm run typecheck                          # lihat catatan di bawah
cd cloud-run/iot-bridge && npm run typecheck               # lihat catatan di bawah
```

Build APK memerlukan JDK + Android SDK; lihat [docs/deployment.md](docs/deployment.md).

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
