# Spesifikasi Induk v0.2 — Firebase + Gemini

Catatan kelanjutan 6 November 2026: berkas ini adalah ringkasan baseline commit `3725af0`. [Dokumen lengkap yang diberikan Product Owner](specifications/SUBAKO_FLUTTER_FIREBASE_GEMINI_MASTER_PROMPT_v0.2.md) kini disertakan tanpa mengubah isi sumber.

Dokumen kanonik `SUBAKO_FLUTTER_FIREBASE_GEMINI_MASTER_PROMPT_v0.2.md`
disediakan Product Owner (Mikiko Technology). Berkas ini mencatat bagian yang
**mengikat implementasi** di repositori ini; bila terjadi perbedaan, dokumen
kanonik milik Product Owner yang berlaku.

## Keputusan produk

- Platform: aplikasi Android native (Flutter + Dart), bahasa Indonesia.
- Backend: **Firebase-first** — Auth, Cloud Firestore, Functions 2nd gen,
  AI Logic, App Check, FCM, Storage, Crashlytics/Performance, Remote Config.
- Tidak membuat backend FastAPI/PostgreSQL baru untuk alur aplikasi normal.
- Gemini hanya melalui **Firebase AI Logic (`firebase_ai`)**; tidak ada API key
  Gemini di aplikasi.
- IoT: ESP32-S3 → LoRaWAN → Gateway → ChirpStack v4 → Cloud Run bridge →
  Firestore. Aplikasi tidak pernah terhubung langsung ke MQTT/ChirpStack.

## Prinsip non-negosiasi

1. Alokasi, giliran, toleransi, dan pengecualian diputuskan Paruman/Pekaseh.
2. Teknologi mengukur, tidak menentukan keadilan.
3. Pintu hanya mengeksekusi aturan sah + interlock lokal.
4. MANUAL fisik selalu menang; E-STOP independen dari aplikasi/Firebase/AI.
5. Pintu tetap dapat dioperasikan manual saat listrik/jaringan/server mati.
6. Gemini advisory: tidak menyetujui aturan, tidak mengirim command, tidak
   mengubah konfigurasi, tidak menimpa keselamatan.
7. Semua aturan, persetujuan, command, ACK, override, dan koreksi ledger
   diaudit.
8. Data stale/missing/simulasi tidak boleh tampil sebagai pengukuran live.
9. Aplikasi/backend/AI bukan lapisan keselamatan utama aktuator.

## Peran

`farmer_viewer`, `operator`, `pekaseh`, `mikiko_admin`, opsional
`platform_admin`; keanggotaan situs eksplisit dan divalidasi server-side.

## Cakupan modul

Dashboard · Monitoring (peta, level, debit, kesehatan) · Gate & command ·
Aturan/jadwal air · Buku Catatan Air · Alert · Laporan · Profil/administrasi ·
SUBAKO AI Assistant.

## Status pemenuhan pada commit ini

Lihat [repository-assessment.md](repository-assessment.md) dan README untuk
matriks status. Hal yang **belum** dipenuhi dan tidak boleh diklaim selesai:
project Firebase nyata, App Check produksi, FCM end-to-end, Gemini produksi,
peta, PDF, dispatcher ChirpStack, dan uji perangkat fisik.
