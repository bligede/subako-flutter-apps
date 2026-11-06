# SUBAKO AI Assistant (Gemini via Firebase AI Logic)

## Status implementasi

- Kontrak asisten: `AiAssistantService` (`lib/services/ai_assistant_service.dart`).
- Konteks terotorisasi dibangun oleh `buildAuthorizedContext` dari data yang
  sudah difilter situs/pengguna.
- Build default memakai `DemoAiAssistantService` (deterministik, tanpa jaringan)
  dan menampilkan label simulasi.
- Build Firebase: `firebase_ai` + `firebase_app_check` sudah menjadi dependensi
  dan `App Check` diaktifkan di `main.dart`. Pemanggilan model dilakukan pada
  adapter produksi yang harus diselesaikan saat project Firebase tersedia —
  **jangan** menambahkan API key Gemini ke aplikasi.

## Batas kewenangan

Asisten hanya menjelaskan. Ia tidak boleh:

- memutuskan/mengubah alokasi atau menyetujui aturan;
- membuat/mengirim command pintu atau mengubah konfigurasi perangkat;
- menimpa MANUAL/E-STOP/interlock;
- menampilkan data situs lain atau menebak angka.

Jika konteks tidak cukup/kedaluwarsa, asisten wajib menyatakan tidak memiliki
data yang cukup dan menyebut status data (LIVE/STALE/OFFLINE/SIMULATION).

## System instruction (ringkas)

> Anda adalah SUBAKO AI Assistant … jawab dalam Bahasa Indonesia … sebutkan
> sumber, lokasi, perangkat, waktu, satuan, dan kualitas data … jangan
> mengarang angka/aturan … rekomendasi operasional bersifat advisory …

Teks lengkap mengikuti spesifikasi v0.2 §12.4 dan disimpan bersama konfigurasi
prompt pada implementasi adapter produksi.

## Function calling

Bila diaktifkan, hanya tool baca: `get_authorized_site_summary`,
`get_latest_water_readings`, `get_device_health`, `get_recent_gate_events`,
`get_active_approved_rule_summary`, `get_alert_details`. Setiap tool wajib
memeriksa auth + situs sendiri; model tidak boleh menentukan otorisasi.

## UI

- Riwayat sesi, quick prompts, indikator mengetik, retry, salin jawaban.
- Chip sumber (situs, perangkat, waktu) dan disclaimer tetap.
- Batas panjang prompt (2.000 karakter) dan jawaban (6.000 karakter).
- Rate limit per pengguna/situs serta pemantauan biaya wajib sebelum rilis.
