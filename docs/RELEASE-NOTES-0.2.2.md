# SUBAKO Flutter 0.2.2 (4) — aplikasi pengguna lapangan

Pemilik mengklarifikasi pembagian produk: Flutter untuk user, PWA untuk dashboard admin. [PRODUCT-SCOPE](PRODUCT-SCOPE.md) mencatat pembagian fitur, status backend saat ini dan urutan integrasi bersama.

- Login menyebut petani, operator dan Pekaseh; shortcut demo admin dihilangkan. Akun dan permission backend tidak dihapus atau diubah.
- Navigasi utama menggunakan Beranda. Monitoring, Operasional, Catatan Air, Profil, alert, laporan, jadwal dan AI tetap tersedia sesuai akses pengguna.
- Profil menampilkan identitas/lokasi Subak dan versi aplikasi; detail UID, kode permission, project Firebase dan model AI dihilangkan dari tampilan pengguna.
- Versi APK menjadi 0.2.2+4; dokumentasi PWA menyatakan lingkup dashboard admin.

Verifikasi: format bersih, Flutter analyze tanpa issue, 30 tes lulus dan kedua APK debug berhasil dibangun serta diverifikasi tanda tangannya. Hash APK dan batas pengujian ada pada [VERIFICATION-0.2.2](VERIFICATION-0.2.2.md).

PWA FastAPI/PostgreSQL dan Flutter Firebase belum memakai identitas/data bersama. Penyambungan backend merupakan pekerjaan integrasi berikutnya yang dijabarkan pada dokumen lingkup. Batas cloud/hardware pada [verifikasi 0.2.1](VERIFICATION-0.2.1.md) tetap berlaku: Gemini belum memberikan jawaban yang terverifikasi, Functions/bridge belum di-deploy, dan command fisik nonaktif.
