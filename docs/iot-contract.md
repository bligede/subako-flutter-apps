# Kontrak IoT

## Uplink (ChirpStack → Cloud Run bridge)

`POST /chirpstack/uplink` dengan header `x-bridge-token`.
Token disimpan di Secret Manager / env server; **tidak pernah** di aplikasi.

```json
{
  "deviceEui": "70B3D57ED0000001",
  "deviceId": "gate-01",
  "siteId": "site-sangeh",
  "sequence": 1024,
  "recordedAt": "2026-11-06T03:12:00.000Z",
  "upstreamCm": 42.5,
  "downstreamCm": 28.1,
  "flowLiterPerSecond": 18.4,
  "batteryPercent": 82,
  "rssi": -78,
  "snr": 6.4,
  "quality": "Baik (kalibrasi 2026-09-12)",
  "source": "DEVICE"
}
```

Validasi bridge:

1. Token cocok (perbandingan constant-time).
2. Skema & rentang nilai valid (`zod`).
3. `deviceId` terdaftar dan `siteId`/`deviceEui` cocok.
4. `recordedAt` tidak lebih tua dari 24 jam.
5. Duplikat/urutan ditangani berdasarkan `sequence` (rencana: dedupe).

Efek: update `telemetryLatest/{deviceId}`, tambah `telemetryEvents`, dan
`alerts` bila baterai < 20%.

## Downlink (aplikasi → perangkat)

```text
Flutter → createGateCommand (callable)
        → validasi auth + membership + permission
        → validasi gate milik situs, mode bukan MANUAL/FAULT
        → validasi aturan PUBLISHED
        → commands/{id} status CREATED (expiresAt 2 menit)
        → Cloud Run command-dispatcher (belum diimplementasikan)
        → ChirpStack API → LoRaWAN → perangkat
        → ACK / feedback posisi → Firestore
```

Aturan yang tidak boleh dilanggar:

- Tidak ada command saat offline dan tidak ada queue otomatis.
- Tidak ada retry otomatis untuk aksi non-idempoten.
- `ACKNOWLEDGED` ≠ `EXECUTED`; `EXECUTED` hanya dari feedback perangkat.
- MANUAL/FAULT/E-STOP selalu menang; interlock lokal authoritative.

## Kesehatan & observability

- `GET /healthz` pada bridge.
- Log terstruktur; payload mentah disimpan terbatas untuk diagnostik.
- Alert dibuat untuk perangkat offline, baterai rendah, sensor anomali.
