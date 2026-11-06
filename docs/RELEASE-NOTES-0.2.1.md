# SUBAKO Android 0.2.1 (3) — opsi Flutter

Kelanjutan foundation yang sudah ada, sebagai aplikasi terpisah dari Web-PWA. Perubahan tidak memigrasikan backend atau mengubah repo Web-PWA.

- Sesi mengikuti auth stream, termasuk logout eksternal dan refresh membership. Site dipilih dari akses pengguna, dengan permission per site; daftar site tidak lagi memakai query tanpa scope.
- Chat dibersihkan saat sesi/site berganti; response yang masih berjalan tidak dapat muncul kembali pada sesi berikutnya. Penghapusan chat memerlukan konfirmasi.
- Adapter Gemini resmi Firebase AI Logic disambungkan ke provider Firebase. Konteks dibatasi ke pembacaan yang diotorisasi; tidak ada command tools. Model lama untuk project baru diganti melalui konfigurasi terpusat.
- Security Rules diperbaiki: membership aktif, akun aktif, audit permission, subcollection default-deny, dan pemisahan get/create/update/delete untuk chat serta FCM tokens. Klien tidak dapat memalsukan pesan assistant.
- Callable memiliki App Check pada cloud; acknowledgement bersifat atomik/idempotent. Endpoint command fisik ditutup. Mutasi online yang belum di-deploy tidak melaporkan sukses palsu.
- Freshness menua lokal, cache ditandai offline, timestamp hilang/data sensor invalid tidak diganti dengan pembacaan nol yang terlihat baru. Grafik hanya menyimpan sampel yang benar-benar diterima di memory tampilan.
- Flavor APK demo dan development, script run/build, konfigurasi emulator dan pengujian layar kecil ditambahkan. Header mobile yang meluber sudah dirapikan.

Project development `subako-dev-mikiko` disiapkan dengan Auth Email/Password, Firestore Jakarta dan fixture SIMULATION. Password serta App Check debug token lokal diabaikan Git. Detail verifikasi aktual dicatat terpisah; keberadaan dependency bukan bukti fitur cloud/hardware sudah diaktifkan.

Yang masih belum merupakan release production: release AAB/signing, Play Integrity pada perangkat rilis, FCM end-to-end, Crashlytics/Performance opt-in, peta, PDF, persistent chat/streaming replies, full rule governance cloud dan ledger sealing independen, command dispatcher, raw IoT ingestion commissioning, backup/restore operasional serta uji lapangan. Build APK tidak membuktikan APK telah dipasang dan diuji pada ponsel nyata.
