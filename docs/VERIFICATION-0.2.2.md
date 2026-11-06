# Verifikasi Flutter 0.2.2 (4) — aplikasi pengguna

Tanggal: 6 November 2026 (WITA). Perubahan dari `f10830e` menyesuaikan aplikasi pengguna dengan pembagian **Flutter untuk user, PWA untuk admin dashboard**. Lihat [PRODUCT-SCOPE](PRODUCT-SCOPE.md) dan [data hasil verifikasi](../evidence/verification-0.2.2.json).

| Pemeriksaan pada versi 0.2.2 | Hasil |
|---|---|
| Dart format | 41 file, tidak ada perubahan format |
| Flutter analyze | Lulus, No issues found |
| Flutter unit/widget | 30 lulus; alur login/navigasi termasuk kembali ke Beranda pada 360/390/768 px |
| APK Demo / Development | Keduanya berhasil dibangun |
| Tanda tangan APK | Keduanya lulus `apksigner.jar verify`, v2 |
| Integritas ZIP APK | Seluruh entry kedua APK dibaca sampai akhir, CRC lulus |
| Pemisahan kredensial | Password online tidak ditemukan di kedua APK; token debug App Check tidak ditemukan pada Demo |
| Perangkat Android nyata | Belum diuji; tidak ada perangkat tersambung |
| Integrasi akun/data Flutter ↔ PWA | Belum diimplementasikan |

Source Functions, IoT bridge, Rules, indeks dan adapter Firebase tidak berubah pada versi ini. Tes Rules (10) dan workflow emulator (5) serta typecheck yang lulus pada [0.2.1](VERIFICATION-0.2.1.md) tidak diulang. Auth/Firestore online dan pertukaran App Check terakhir lulus pada probe `2026-11-06T15:14:31.460Z`; generasi Gemini dan probe enforcement timeout. Probe cloud tidak diulang untuk perubahan presentasi ini.

Kedua APK memakai versionName `0.2.2`, versionCode `4`, minimum Android 7 / API 24, target API 36; application ID demo `id.mikiko.subako.demo` dan development `id.mikiko.subako`.

| File | Byte | SHA-256 |
|---|---:|---|
| `SUBAKO-Demo-0.2.2-debug.apk` | 182804915 | `6f833b38650f9e03756ace52eefeb5257e9240df8bb89d96e5c31b8ad1109f50` |
| `SUBAKO-Development-0.2.2-debug.apk` | 182805039 | `76d96fc57f0f8f0795174e74c0a1ade23b52440ee0e2ccc6932bb4a6c9611d15` |

Demo login: `petani@subako.demo`, `operator@subako.demo`, atau `pekaseh@subako.demo`, sandi `Subako#2026`. Kredensial Firebase tetap berada dalam `.local/firebase-demo-credentials.json`. APK Development memuat token debug App Check dan merupakan artefak privat. Source ZIP/Git tidak memuat `.local/`, APK atau kredensial privat.

Dokumentasi lingkup PWA dipush pada branch `feature/admin-dashboard-scope`, commit `ef62842`. Tidak ada perubahan runtime PWA atau migrasi database pada iterasi ini. Backend kedua client belum terhubung. Functions/IoT bridge belum di-deploy dan perintah fisik tetap nonaktif; versi ini masih development.
