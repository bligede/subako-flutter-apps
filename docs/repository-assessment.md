# Penilaian Repositori — SUBAKO Flutter v0.2

Tanggal: 6 November 2026

## Kondisi awal

- Repositori `bligede/subako-flutter-apps` **kosong** (tanpa commit, tanpa branch).
- Tidak ada kode Flutter, aset desain, atau riwayat yang perlu dipertahankan.
- Repositori implementasi lain (`subako-web-apps-by-mikiko`) memuat backend
  FastAPI/PostgreSQL dari Phase 1 dan **tidak disentuh** oleh pekerjaan ini.

## Keputusan arsitektur

1. **Firebase-first**: Firebase Auth + Cloud Firestore + Cloud Functions 2nd gen
   adalah backend kanonik untuk aplikasi Android ini dan Web-PWA berikutnya.
2. **Tidak ada backend FastAPI baru** untuk alur aplikasi normal.
3. **Gemini hanya lewat Firebase AI Logic** (`firebase_ai`), tanpa API key di
   aplikasi. Pada build ini adapter AI Firebase disiapkan sebagai langkah
   berikutnya; build default memakai asisten demo deterministik.
4. **IoT tidak pernah langsung dari aplikasi**: uplink melalui Cloud Run bridge
   (`cloud-run/iot-bridge`) dan downlink melalui Functions + dispatcher.
5. **Build demo tanpa Firebase** wajib berjalan penuh agar UI/UX dan aturan
   domain dapat diuji sebelum project Firebase tersedia.

## Yang dikerjakan pada iterasi ini

- Fondasi Flutter (Material 3, Riverpod, go_router, tema brand SUBAKO).
- Model domain, RBAC, state machine command, hash chain ledger, freshness data.
- Repository ganda: `DemoRepository` (SIMULATION) dan `FirebaseRepository`.
- Layar: splash, onboarding, login, dashboard, monitoring, gate + detail,
  aturan air + detail, Buku Catatan Air, alert, laporan, AI assistant, profil.
- Firestore rules default-deny, indexes, Functions callable, IoT bridge.
- Unit test, widget test, dokumentasi, README, dan CI.

## Keterbatasan yang disengaja (jujur)

- Project Firebase, App Check, FCM, dan Gemini **belum dikonfigurasi** karena
  memerlukan akses Firebase Console milik Product Owner.
- Peta hanya placeholder; provider peta belum dipilih.
- PDF export belum ada; laporan mengekspor CSV.
- Command dispatcher ChirpStack belum diimplementasikan (hanya kontrak dan
  model command). Tidak ada perangkat fisik yang dapat menerima perintah dari
  build ini.
- Build APK memerlukan Android SDK/JDK; lihat `docs/deployment.md`.
