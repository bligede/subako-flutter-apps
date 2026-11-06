# Menjalankan opsi Flutter SUBAKO

Opsi Android ini terpisah dari Web-PWA. Baseline repo dipertahankan pada commit `3725af0`; kelanjutan berada di branch `feature/flutter-option-v0.2`. Flutter dipin ke **3.47.9 / Dart 3.13.7**. Pada mesin kerja SDK khusus tersedia di `D:/Wahyu/.tools/flutter-subako`; SDK global tidak diubah.

## Demo tanpa cloud

```powershell
flutter pub get
flutter run --flavor demo --dart-define=SUBAKO_FIREBASE_ENABLED=false
```

Untuk membuat APK development:

```powershell
flutter build apk --debug --flavor demo --dart-define=SUBAKO_FIREBASE_ENABLED=false
```

APK hasil build berada di `build/app/outputs/flutter-apk/app-demo-debug.apk`. Application ID demo adalah `id.mikiko.subako.demo`, berbeda dari Firebase development `id.mikiko.subako`. Akun demo lokal: `petani@subako.demo`, `operator@subako.demo`, `pekaseh@subako.demo`, `admin@subako.demo`, dengan sandi **`Subako#2026`**. Chip pada layar login mengisi akun demo secara langsung. Kredensial ini hanya mengakses simulator di dalam aplikasi; tidak berlaku untuk Firebase online.

Shortcut Windows: `tools/run-android.ps1 -Environment demo -Build`. Jika SDK pada PATH terlalu lama, tambahkan `-FlutterSdk D:/Wahyu/.tools/flutter-subako`. Hilangkan `-Build` untuk menjalankan pada perangkat/emulator Android yang sudah tersambung.

## Project Firebase development

- Project ID: `subako-dev-mikiko`; dibuat sesuai permintaan pengguna.
- Android app: `id.mikiko.subako`.
- Firestore: `(default)`, native standard, `asia-southeast2` (Jakarta).
- Authentication: Email/Password, aktivasi awal dilakukan pemilik melalui Firebase Console.
- Rules dan indeks berasal dari repository, dengan default-deny dan membership aktif.

Konfigurasi client lokal disimpan di `.local/google-services.json` dan `.local/firebase-development.json`. File yang memuat debug App Check token serta password akun development tidak masuk Git. Akun Firebase memakai email `...@demo.subako.local` dan **sandi acak tersendiri** di `.local/firebase-demo-credentials.json`; jangan memakai sandi demo lokal untuk login Firebase.

```powershell
flutter run --flavor development --dart-define-from-file=.local/firebase-development.json
```

SDK diinisialisasi dengan FirebaseOptions dari identifier project resmi dan Dart defines. Untuk environment lain, daftarkan app/project milik environment tersebut dan gunakan FlutterFire CLI untuk mendapatkan konfigurasi platform yang sesuai; jangan menyalin project development sebagai production. Identifier/API key client Firebase tidak menggantikan authorization. Tidak ada API key Gemini, service account, atau signing key yang dimasukkan ke aplikasi.

Tool `tools/provision-development.cjs` dibatasi ke project development ini dan memakai sesi login Firebase CLI pada komputer pemilik. `--seed` membuat fixture SIMULATION dan akun dengan sandi acak secara idempotent; akun yang sudah ada tidak direset. Tool tersebut memerlukan `npm ci` di root dan `functions/`. Ia bukan workflow provisioning production.

## Firebase AI Logic

Adapter Android menggunakan `firebase_ai`, dengan konteks baca-saja yang diambil ulang dari site yang boleh diakses pengguna. Model dipilih melalui `SUBAKO_GEMINI_MODEL`; default mengikuti model yang tersedia untuk project baru pada waktu verifikasi. Tidak ada actuator/rule-write tools.

Debug App Check token dibuat dan didaftarkan untuk development saja oleh `tools/configure-appcheck.cjs`. Nilainya hanya berada dalam `.local/firebase-development.json`. APK development yang mengandung token tersebut merupakan artefak privat; distribusikan APK demo untuk review umum. Sebelum release gunakan Play Integrity dan registrasi certificate yang sesuai. Release menolak debug App Check/emulator.

`SUBAKO_GEMINI_ENABLED=true` pada konfigurasi development privat sesudah pemilik mengonfirmasi setup AI Logic dan App Check Enforced di Console. Model yang dikonfigurasi adalah `gemini-3.8-flash`. Pertukaran debug App Check token berhasil, tetapi probe generasi dan probe penolakan tanpa App Check masih timeout dari mesin kerja; jawaban Gemini online dan enforcement belum terverifikasi secara independen. Aplikasi menampilkan kegagalan request dan tidak menggantinya dengan jawaban demo. Lihat [laporan verifikasi](VERIFICATION-0.2.1.md).

APK development belum dipasang pada perangkat Android dalam pekerjaan ini. Gunakan akun dari file kredensial lokal untuk uji perangkat berikutnya. APK demo dapat dipasang pada Android 7 (API 24) ke atas; demo dan development dapat terpasang bersamaan karena application ID berbeda.

## Workflow tepercaya dan biaya cloud

Project tidak dihubungkan ke akun billing oleh pekerjaan ini. Cloud Functions/Cloud Run belum di-deploy online. `SUBAKO_TRUSTED_FUNCTIONS=false` adalah default: mutation workflow online ditolak dengan pesan yang jelas. Demo lokal tetap dapat dipakai untuk mencoba interaksi.

Pada development tanpa Functions, konteks AI diambil melalui Firebase client reads yang dibatasi Security Rules, dengan query site-scoped dan batas jumlah record. Untuk environment dengan Functions yang sudah diuji/deploy, aktifkan `SUBAKO_TRUSTED_FUNCTIONS=true`; `getAiContext` menerapkan Auth, membership, permission, App Check dan rate limit konteks server. Rate limit konteks tersebut bukan pembatas menyeluruh untuk semua request langsung Firebase AI Logic; tetapkan quota/budget pada project sebelum distribusi luas.

Pintu fisik tetap tidak dapat dikendalikan: callable `createGateCommand` selalu menolak sampai integrasi dan commissioning dirancang/diuji. Jangan menghubungkan dispatcher yang menganggap `SET_POSITION` demo sebagai wire protocol controller engineering.

## Emulator dan tes

Memerlukan JDK 21 serta Node.js 24 untuk tooling:

```powershell
npm ci
npm --prefix functions ci
npm --prefix cloud-run/iot-bridge ci
npm run test:rules
npm run test:backend
flutter analyze
flutter test
```

Emulator project selalu `demo-subako`, port Auth 9099, Firestore 8085 dan Functions 5001; tidak memakai project online. `config/emulator.example.json` berisi identifier dummy khusus emulator. Android emulator mengakses host melalui `10.0.2.2`, sedangkan perangkat fisik memerlukan forwarding/host yang sesuai. Firebase Functions emulator memakai credential fixture lokal dan Auth Emulator token dalam tes; tidak ada test yang mengirim command ke perangkat.

```powershell
npm --prefix functions run build
npm run emulators
flutter run --flavor development --dart-define-from-file=config/emulator.example.json
```

Fixture Auth/Firestore untuk tes dibuat oleh runner, bukan otomatis tersimpan untuk sesi emulator interaktif. Gunakan Emulator UI atau script seed fixture yang ditinjau sebelum menjalankan UI interaktif.

## Batas dan pemulihan

Firestore snapshot dapat dibaca dari cache Android, tetapi ditandai OFFLINE; freshness dihitung ulang secara lokal meskipun tidak ada event baru. Tidak ada client write queue untuk command/approval. Semua mutasi cloud berupa callable online dengan timeout dan tanpa automatic replay. Riwayat chat hanya berada di memory sesi dan dibersihkan pada logout/pergantian site; belum ada kebijakan persistensi chat atau full vector RAG.

Untuk mengembalikan source gunakan commit/branch yang tercatat. Jangan menghapus project, database, akun atau membership sebagai cara reset UI. Penggantian credential/seed bukan proses restore database. Backup/restore cloud terjadwal, release signing, FCM delivery, field hardware tests dan production commissioning tetap memerlukan tahap berikutnya.

Referensi resmi: [Flutter archive](https://docs.flutter.dev/install/archive), [Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started), [model yang didukung](https://firebase.google.com/docs/ai-logic/models), [App Check debug tokens](https://firebase.google.com/docs/reference/appcheck/rest/v1/projects.apps.debugTokens/create), [Firebase Rules testing](https://firebase.google.com/docs/rules/unit-tests).
