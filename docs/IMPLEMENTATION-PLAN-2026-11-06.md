# Kelanjutan opsi Flutter — 6 November 2026

> Klarifikasi lingkup setelah iterasi awal: **Flutter untuk user lapangan, PWA untuk admin dashboard**. Dokumen ini merekam rencana awal; acuan pembagian produk terbaru ada pada [PRODUCT-SCOPE](PRODUCT-SCOPE.md). Integrasi backend kedua client belum selesai.

Permintaan pengguna: membuat opsi aplikasi Flutter terpisah dari Web-PWA. Repositori Android yang ditemukan sudah berisi commit `3725af0` pada default branch `feature/firebase-gemini-backend-v0.2`. Pekerjaan diteruskan pada `feature/flutter-option-v0.2`; baseline tersebut dipertahankan dan Web-PWA tidak dimigrasikan.

## Penilaian awal

- Sudah ada Flutter/Riverpod/go_router, dashboard, monitoring, rules, ledger, alert, laporan dan chat demo; Firebase repository, Functions, Rules dan bridge TypeScript tersedia.
- AI provider masih selalu memakai demo deterministik. Inisialisasi Firebase dan App Check belum memiliki konfigurasi environment yang tervalidasi. Profil Firebase awal mengasumsikan role viewer; pemilihan site masih dikunci pada `site-sangeh`.
- Security Rules belum memiliki hasil emulator; operasi chat/token menggabungkan read/write dengan field yang tidak tersedia pada semua jenis request.
- APK belum dibangun pada mesin ini. SDK Flutter global 3.41.9/Dart 3.11.5 tidak memenuhi constraint repo Dart 3.13. Toolchain Android/JDK tersedia di `D:/Wahyu/.tools`, tetapi tidak ada perangkat Android tersambung.
- Akses Firebase CLI tersedia. Tidak ada project SUBAKO pada daftar yang dapat diakses; pemilihan project online diminta terpisah. Nama project dalam `.firebaserc` baseline adalah contoh, bukan bukti provisioning.

## Urutan pekerjaan

1. Gunakan SDK Flutter stable yang kompatibel tanpa mengganti SDK global. Pulihkan dependency dan jalankan pemeriksaan baseline.
2. Lengkapi bootstrap Firebase/emulator, state sesi, site scope, freshness dan Gemini adapter resmi `firebase_ai`, dengan demo yang tetap terpisah dan label yang jelas.
3. Uji dan perbaiki Rules dengan emulator. Verifikasi Functions/bridge dan nonaktifkan jalur aktuasi fisik yang belum diimplementasikan atau diuji.
4. Jalankan format, analyze, unit/widget/integration, Rules tests, TypeScript checks dan build APK development. Tangkap bukti UI serta dokumentasikan fitur yang masih memerlukan konfigurasi cloud/perangkat.
5. Sediakan APK, panduan setup, hasil verifikasi, dan push branch implementasi. Jangan merge default branch atau mengklaim deployment Firebase/Gemini online sebelum diverifikasi.

Pilihan Firebase-first pada aplikasi ini tidak otomatis mengubah backend Web-PWA yang sudah disetujui. AI hanya advisory; tidak memiliki actuator/rule-write tools. Cloud production, billing, release signing dan hardware commissioning belum menjadi hasil yang bisa diklaim dalam iterasi ini.
