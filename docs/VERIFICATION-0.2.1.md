# Verifikasi SUBAKO Flutter 0.2.1 (3)

Tanggal: 6 November 2026 (WITA). Baseline `3725af0aca4c8c7e29367a44d3aff4fca46f9a8c`, branch kelanjutan `feature/flutter-option-v0.2`. Laporan ini membedakan tes lokal, akses cloud aktual, dan pekerjaan yang belum diverifikasi. Data terstruktur: [verification-0.2.1.json](../evidence/verification-0.2.1.json).

## Hasil lokal

| Pemeriksaan | Hasil |
|---|---|
| Flutter analyze | Lulus, No issues found |
| Unit/widget Flutter | 30 lulus, termasuk sesi/site, password salah, freshness dan alur layar 360/390/768 px |
| Firestore Security Rules emulator | 10 lulus: scope membership, permission, default-deny dan chat/token ownership |
| Functions workflow emulator | 5 lulus: Auth nyata dari emulator, penolakan lintas site, konteks terbatas, acknowledgement atomik/idempotent, pencabutan akses dan penolakan command fisik |
| Functions TypeScript build | Lulus |
| IoT bridge TypeScript typecheck | Lulus; tidak membuktikan ingest perangkat fisik |
| APK Demo debug | Build lulus; signature v2 dan CRC ZIP lulus |
| APK Development debug | Build lulus; signature v2 dan CRC ZIP lulus |
| Flutter web preview | Build lulus; pemeriksaan browser headless timeout, tidak dihitung sebagai uji UI browser lulus |
| CI workflow | Dikonfigurasi untuk analyze, tes, build demo APK dan emulator; hasil CI remote harus diperiksa terpisah |

Total 45 tes otomatis lulus. Emulator menggunakan project `demo-subako` dan tidak mengirim command ke hardware. Pengujian widget bukan bukti instalasi atau UAT pada ponsel Android.

Toolchain: Flutter 3.47.9, Dart 3.13.7, JDK 21.0.12.1, Android SDK/build-tools 36, Node 24.19.0. SDK Flutter dipasang terpisah dari SDK global. Gradle memakai Kotlin compiler in-process untuk menghindari masalah cache lintas drive C:/D: pada Windows.

## Firebase online

Project development khusus: `subako-dev-mikiko`, Firestore Jakarta (`asia-southeast2`). Rules dan indeks dari source sudah berhasil di-deploy. Tidak ada billing account yang dihubungkan oleh pekerjaan ini.

| Probe aktual | Hasil |
|---|---|
| Email/Password sign-in akun development | HTTP 200 |
| Pembacaan site yang diizinkan dengan ID token pengguna | HTTP 200 |
| Pembacaan site yang tidak diizinkan | HTTP 403 |
| Pertukaran debug token App Check | HTTP 200 |
| App Check Enforced untuk AI Logic | Dikonfirmasi pemilik melalui Console; probe tanpa token timeout, belum diverifikasi independen |
| Respons Gemini melalui Firebase AI Logic | Timeout; belum memperoleh jawaban yang terverifikasi |

Probe cloud diulang pada `2026-11-06T15:14:31.460Z`: Auth, scope Firestore dan pertukaran App Check tetap lulus; generasi serta probe enforcement masih timeout. Model development dikonfigurasi `gemini-3.8-flash` setelah model sebelumnya ditolak untuk project baru. Konfigurasi Gemini di APK development diaktifkan berdasarkan konfirmasi setup Console, **bukan berdasarkan keberhasilan generasi**. UI menampilkan kegagalan request; tidak ada fallback jawaban demo di sesi Firebase.

Fixture online berlabel SIMULATION dan berupa sampel statis. Simulator dinamis di APK Demo berjalan lokal. Tidak ada klaim data sensor lapangan tersedia.

## APK dan instalasi

Kedua APK adalah **debug build**, minimum Android 7 / API 24, target API 36, ABI `arm64-v8a`, `armeabi-v7a`, `x86_64`, versionName `0.2.1`, versionCode `3`.

| File | Application ID | Ukuran (byte) |
|---|---|---:|
| `SUBAKO-Demo-0.2.1-debug.apk` | `id.mikiko.subako.demo` | 182800795 |
| `SUBAKO-Development-0.2.1-debug.apk` | `id.mikiko.subako` | 182805447 |

SHA-256:

```text
17a3a0ee9943bf1ae91209eac4f92b7c682e60ad22fc9ede932a1df6d0aea6f6  SUBAKO-Demo-0.2.1-debug.apk
84396159f779a56e89c996dd238a4ee7d83a7d04fe3f1227c76eef50f2b3b876  SUBAKO-Development-0.2.1-debug.apk
```

Sertifikat debug SHA-256: `5909a5ee09f51c4c2d7c35d23adad0fbe0c324b04cb8dab28ea1d871af98e50a`. `apksigner.jar verify --verbose --print-certs` lulus untuk keduanya. CRC seluruh entry ZIP lulus, password online tidak ditemukan di kedua paket, dan token debug App Check tidak ditemukan pada APK Demo.

APK Development memuat debug App Check token untuk pengujian privat. Jangan distribusikan secara publik. File konfigurasi dan sandi cloud berada di `.local/` yang diabaikan Git; APK, log dan file kredensial tidak masuk source ZIP atau GitHub. Akun demo lokal: `pekaseh@subako.demo`, sandi `Subako#2026`. Akun online memakai domain `demo.subako.local` dan sandi acak dalam `.local/firebase-demo-credentials.json` pada mesin pemilik.

Salin APK ke perangkat, buka file lalu izinkan instalasi dari aplikasi pengirim bila Android meminta. Demo dan Development dapat dipasang bersamaan. Belum ada perangkat Android tersambung untuk memverifikasi instalasi, alur login, App Check native atau jawaban Gemini dari APK.

## Pekerjaan berikutnya

- Uji perangkat Android nyata, termasuk lifecycle, jaringan putus, akses Firebase dan diagnosis timeout Gemini.
- Deployment Functions/Cloud Run dengan billing yang dipilih pemilik; mutasi cloud masih nonaktif secara default.
- Release signing/AAB dan Play Integrity; debug token tidak boleh dipakai sebagai konfigurasi production.
- FCM end-to-end, peta/PDF, chat persisten, governance cloud lengkap, ledger sealing dan backup/restore operasional.
- Integrasi LoRaWAN/controller, keselamatan lokal dan commissioning lapangan. Endpoint command fisik tetap menolak semua permintaan.

Versi ini adalah fondasi development yang dapat ditinjau dan dicoba, belum memenuhi seluruh lingkup production pada master prompt v0.2.
