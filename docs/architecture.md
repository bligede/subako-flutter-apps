# Arsitektur SUBAKO v0.2

Prinsip: **Tradisi memutuskan. Teknologi mengukur. SUBAKO mengeksekusi.**

Pembagian client yang diklarifikasi pemilik: **Flutter untuk user lapangan, PWA untuk dashboard admin**. Lihat [PRODUCT-SCOPE](PRODUCT-SCOPE.md). Diagram di bawah menunjukkan arsitektur backend Flutter yang sudah disiapkan. Target PWA memakai data kanonik yang sama melalui API admin; adapter tersebut belum dibuat. Runtime PWA saat ini tetap FastAPI/PostgreSQL dengan sesi dan dataset terpisah.

```text
┌──────────────────────────┐
│ Flutter Android (app)    │
│ Riverpod + go_router     │
└────────────┬─────────────┘
             │ Firebase SDK (Auth, Firestore read, callable Functions)
┌────────────▼─────────────┐
│ Firebase                 │
│  Auth · Firestore · FCM  │
│  Functions (2nd gen)     │
│  AI Logic (Gemini)       │
│  App Check               │
└────────────┬─────────────┘
             │ Admin SDK (server-side only)
┌────────────▼─────────────┐
│ Cloud Run IoT Bridge     │
│  validasi + normalisasi  │
└────────────┬─────────────┘
             │ HTTPS webhook / MQTT (server-side)
┌────────────▼─────────────┐
│ ChirpStack v4 → LoRaWAN  │
│ Gateway → ESP32-S3       │
└──────────────────────────┘
```

## Alur uplink

`ESP32-S3 → RAK3172/LoRaWAN → Gateway → ChirpStack → Cloud Run bridge →
validasi skema/identitas/waktu → telemetryLatest + telemetryEvents (+ alert)`

Bridge menolak payload tidak valid, perangkat tidak dikenal, mismatch situs,
dan uplink lebih tua dari 24 jam.

## Alur downlink (kontrak, belum aktif ke perangkat)

`Flutter → callable createGateCommand → validasi peran/aturan/mode → dokumen
commands(CREATED) → dispatcher Cloud Run → ChirpStack API → perangkat →
ACK/feedback → Firestore`

Status command: `CREATED → VALIDATING → QUEUED → SENT → ACKNOWLEDGED →
EXECUTED`, dengan status terminal `REJECTED/EXPIRED/FAILED/TIMED_OUT/CANCELLED`.
**ACK bukan EXECUTED.**

## Batas keamanan

- Klien tidak pernah menulis koleksi authoritative (rules default-deny).
- Admin SDK melewati rules, sehingga Functions/bridge melakukan otorisasi
  eksplisit (membership + permission).
- Aplikasi tidak pernah menyimpan API key Gemini; akses lewat AI Logic +
  App Check.
- Mode MANUAL/FAULT/E-STOP dan interlock fisik selalu menang atas aplikasi.

## Mode demo

Tanpa `SUBAKO_FIREBASE_ENABLED=true`, aplikasi memakai `DemoRepository`
in-memory dengan label `SIMULATION` di setiap kartu. AI memakai
`DemoAiAssistantService` deterministik dan menandai jawabannya sebagai simulasi.
