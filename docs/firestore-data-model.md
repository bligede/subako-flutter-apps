# Model Data Firestore

## Koleksi

| Koleksi | Isi | Penulis |
|---|---|---|
| `users/{uid}` | profil, peran platform, `siteIds` | Functions |
| `sites/{siteId}` | nama, desa, kabupaten, jumlah tempek/gate | Functions |
| `sites/{siteId}/members/{uid}` | `role`, `permissions[]` | Functions |
| `sites/{siteId}/tempeks/{id}` | metadata tempek | Functions |
| `devices/{deviceId}` | gate/node/gateway, mode, firmware, `siteId`, `lastSeen` | Functions/bridge |
| `gateways/{gatewayId}` | metadata gateway LoRaWAN | Functions |
| `telemetryLatest/{deviceId}` | satu snapshot terbaru per perangkat | bridge |
| `telemetryEvents/{id}` | event terpilih / tersampel | bridge |
| `waterRules/{ruleId}` | aturan aktif + status siklus | Functions |
| `waterRules/{ruleId}/versions/{v}` | arsip versi immutable | Functions |
| `waterSchedules/{id}` | jadwal turunan aturan | Functions |
| `commands/{commandId}` | siklus command aktuator | Functions |
| `gateEvents/{id}` | feedback pintu (posisi, limit, fault) | bridge |
| `waterLedger/{entryId}` | entri append-only dengan `prevHash`/`hash` | Functions |
| `ledgerSeals/{id}` | seal harian (opsional) | Functions |
| `alerts/{id}` | alert + acknowledgement | bridge/Functions |
| `auditEvents/{id}` | jejak audit append-only | Functions |
| `chatSessions/{id}` + `messages` | riwayat chat milik pengguna | klien (rules owner-only) |

## Field wajib

Setiap record operasional memuat: `siteId` (bila relevan), `createdAt`/
`updatedAt` (server timestamp), `createdBy`/`actorUid`, `source`
(`DEVICE|SYSTEM|USER|SIMULATOR|AI`), dan `dataState`
(`LIVE|STALE|OFFLINE|SIMULATION`).

Timestamp disimpan UTC (`Timestamp`), ditampilkan WITA (UTC+8) oleh
`Formatters`.

## Invarian

- Aturan `PUBLISHED` tidak diubah in-place; perubahan membuat versi baru.
- Ledger tidak pernah di-update/delete; koreksi = entri baru dengan
  `correctionOf`.
- Command tidak disimpan untuk dikirim ulang saat reconnect.
- `telemetryLatest` hanya nilai terbaru; bukan pengganti time series.
- Chat hanya dapat dibaca pemiliknya (`ownerUid`).

## Kebijakan volume telemetri

- `telemetryLatest`: 1 dokumen per perangkat, write tiap uplink.
- `telemetryEvents`: hanya event bermakna/tersampel; hindari write
  high-frequency tanpa kajian biaya.
- Riwayat rapat dan analitik jangka panjang: arahkan ke Pub/Sub → BigQuery
  atau Cloud Storage (belum diaktifkan pada MVP).
- Retensi, read/write rate, dan indeks harus ditinjau sebelum pilot.

## Index komposit

Lihat `firestore.indexes.json`: `alerts(siteId, raisedAt)`,
`commands(siteId, createdAt)`, `waterLedger(siteId, recordedAt)`,
`waterRules(siteId, updatedAt)`, `devices(siteId, kind)`,
`telemetryEvents(siteId, recordedAt)`.
