# Firestore Security Rules

## Prinsip

- **Default deny** untuk seluruh path.
- Semua akses data situs memerlukan autentikasi + keanggotaan situs.
- Klien **tidak** menulis koleksi authoritative: telemetri, aturan, ledger,
  command, alert, audit, perangkat.
- Admin SDK (Functions/bridge) melewati rules → otorisasi eksplisit wajib di
  kode server.

## Ringkasan aturan

| Path | Baca | Tulis |
|---|---|---|
| `users/{uid}` | pemilik | tidak ada |
| `sites/{siteId}/**` | anggota situs | tidak ada |
| `devices`, `gateways`, `telemetryLatest`, `telemetryEvents` | anggota situs | tidak ada |
| `waterRules` (+ `versions`), `waterSchedules` | anggota situs | tidak ada |
| `commands`, `gateEvents`, `waterLedger`, `ledgerSeals` | anggota situs | tidak ada |
| `alerts`, `auditEvents` | anggota situs | tidak ada |
| `chatSessions/{id}/messages` | pemilik (`ownerUid`) | pemilik |
| `fcmTokens/{id}` | pemilik | pemilik |

Query klien selalu memfilter `siteId`, sehingga aturan list dapat dievaluasi.

## Yang belum diverifikasi

- Uji Rules dengan Firebase Emulator Suite (`@firebase/rules-unit-testing`)
  belum dijalankan pada lingkungan ini karena emulator memerlukan Java dan
  project Firebase. Rencana uji:
  1. pengguna anonim ditolak;
  2. anggota situs A tidak dapat membaca data situs B;
  3. `farmer_viewer` tidak dapat membuat command;
  4. klien tidak dapat menulis ledger/command/telemetry;
  5. sesi chat pengguna lain ditolak;
  6. eskalasi peran lewat update dokumen sendiri ditolak.

- App Check (Play Integrity) harus diaktifkan sebelum rilis; token debug hanya
  untuk lokal dan tidak boleh di-commit.
