import '../core/config/app_config.dart';
import '../shared/models/models.dart';

/// Konteks minimal yang boleh dikirim ke Gemini.
///
/// Hanya berisi data yang sudah lolos otorisasi situs/pengguna.
class AiContext {
  const AiContext({
    required this.siteName,
    required this.telemetrySummary,
    required this.gateSummary,
    required this.activeRuleSummary,
    required this.dataState,
    required this.capturedAt,
    this.alertsSummary = '',
  });

  final String siteName;
  final String telemetrySummary;
  final String gateSummary;
  final String activeRuleSummary;
  final String alertsSummary;
  final String dataState;
  final DateTime capturedAt;
}

class AiReply {
  const AiReply({
    required this.text,
    this.sources = const <String>[],
    this.isFallback = false,
  });

  final String text;
  final List<String> sources;
  final bool isFallback;
}

abstract class AiAssistantService {
  Future<AiReply> ask({required String prompt, required AiContext context});
}

/// Implementasi demo: jawaban deterministik dari konteks, tanpa panggilan AI.
///
/// Tetap mematuhi batas kewenangan: tidak memberi perintah aktuator, tidak
/// mengubah aturan, dan selalu menyebut waktu serta status data.
class DemoAiAssistantService implements AiAssistantService {
  const DemoAiAssistantService();

  @override
  Future<AiReply> ask({
    required String prompt,
    required AiContext context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final String normalized = prompt.toLowerCase();
    final List<String> sources = <String>[
      '${context.siteName} • ${context.dataState}',
      'Snapshot ${context.capturedAt.toIso8601String()}',
    ];

    if (normalized.contains('pintu') || normalized.contains('gate')) {
      return AiReply(
        text:
            'Status pintu saat ini: ${context.gateSummary}. Posisi tersebut '
            'dilaporkan perangkat, bukan hasil perintah aplikasi. Saya tidak '
            'dapat membuka/menutup pintu atau mengubah konfigurasi perangkat. '
            'Untuk tindakan operasional, verifikasi melalui Operator/Pekaseh '
            'sesuai prosedur dan interlock lokal.\n\n'
            'Data: ${context.dataState} pada ${context.capturedAt.toIso8601String()} WITA.',
        sources: sources,
        isFallback: true,
      );
    }
    if (normalized.contains('aturan') || normalized.contains('jadwal')) {
      return AiReply(
        text:
            'Aturan yang berlaku: ${context.activeRuleSummary}. Saya hanya '
            'menjelaskan aturan yang sudah disahkan; keputusan alokasi tetap '
            'milik Paruman/Pekaseh.\n\n'
            'Catatan: ${AppConfig.aiDisclaimer}',
        sources: sources,
        isFallback: true,
      );
    }
    if (normalized.contains('alert') || normalized.contains('peringatan')) {
      return AiReply(
        text:
            'Ringkasan alert: ${context.alertsSummary.isEmpty ? 'tidak ada alert aktif.' : context.alertsSummary}. '
            'Severity, waktu, dan bukti teknis perlu diverifikasi di layar '
            'Alert. Untuk kondisi kritis (E-STOP/FAULT), ikuti prosedur '
            'keselamatan setempat dan hubungi petugas kompeten.\n\n'
            'Data: ${context.dataState}.',
        sources: sources,
        isFallback: true,
      );
    }
    return AiReply(
      text:
          'Ringkasan ${context.siteName}: ${context.telemetrySummary}. '
          'Status data: ${context.dataState} (snapshot ${context.capturedAt.toIso8601String()}). '
          'Saya asisten informasi; saya tidak memutuskan pembagian air, tidak '
          'menyetujui aturan, dan tidak mengirim perintah pintu.\n\n'
          '${AppConfig.aiDisclaimer}',
      sources: sources,
      isFallback: true,
    );
  }
}

/// Membangun konteks dari model yang sudah difilter hak aksesnya.
AiContext buildAuthorizedContext({
  required Site site,
  required TelemetrySnapshot telemetry,
  required List<Device> devices,
  required List<WaterRule> rules,
  required List<Alert> alerts,
}) {
  final String gates = devices
      .where((Device d) => d.isGate)
      .map(
        (Device d) =>
            '${d.name} mode ${d.mode.label}, posisi ${d.positionPercent?.toStringAsFixed(0) ?? '?'}%',
      )
      .join('; ');
  final WaterRule? active = rules
      .where((WaterRule r) => r.status.isActive)
      .cast<WaterRule?>()
      .firstWhere((WaterRule? _) => true, orElse: () => null);
  final List<Alert> openAlerts = alerts
      .where((Alert a) => !a.acknowledged)
      .toList(growable: false);

  return AiContext(
    siteName: site.name,
    telemetrySummary:
        'level hulu ${telemetry.upstreamCm.toStringAsFixed(1)} cm, '
        'hilir ${telemetry.downstreamCm.toStringAsFixed(1)} cm, '
        'debit ${telemetry.flowLiterPerSecond.toStringAsFixed(1)} L/detik '
        '(kualitas: ${telemetry.quality})',
    gateSummary: gates.isEmpty ? 'tidak ada gate terdaftar' : gates,
    activeRuleSummary: active == null
        ? 'tidak ada aturan PUBLISHED'
        : '${active.id} v${active.version} untuk ${active.tempek}, '
              'porsi ${(active.allocationShare * 100).toStringAsFixed(0)}%, '
              '${active.scheduleLabel}, referensi ${active.parumanReference}',
    alertsSummary: openAlerts
        .map((Alert a) => '${a.severity.displayName}: ${a.title}')
        .join('; '),
    dataState: telemetry.dataState.label,
    capturedAt: telemetry.recordedAt,
  );
}
