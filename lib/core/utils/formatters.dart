import 'package:intl/intl.dart';

/// Format tanggal/jam konsisten untuk UI SUBAKO.
///
/// Timestamp disimpan UTC, ditampilkan dalam WITA (UTC+8, Asia/Makassar).
class Formatters {
  const Formatters._();

  static const Duration witaOffset = Duration(hours: 8);

  static DateTime toWita(DateTime value) => value.toUtc().add(witaOffset);

  static DateTime fromWita(DateTime value) => value.subtract(witaOffset);

  static String dateTime(DateTime value) {
    final DateTime wita = toWita(value);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(wita);
  }

  static String time(DateTime value) {
    final DateTime wita = toWita(value);
    return DateFormat('HH:mm', 'id_ID').format(wita);
  }

  static String date(DateTime value) {
    final DateTime wita = toWita(value);
    return DateFormat('dd MMM yyyy', 'id_ID').format(wita);
  }

  static String relative(DateTime value, {DateTime? now}) {
    final Duration diff = (now ?? DateTime.now()).toUtc().difference(
      value.toUtc(),
    );
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds.clamp(0, 59)} detik lalu';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    }
    return '${diff.inDays} hari lalu';
  }

  static String volume(double cubicMeter) =>
      '${cubicMeter.toStringAsFixed(2)} m³';

  static String literPerSecond(double value) =>
      '${value.toStringAsFixed(2)} L/detik';

  static String centimeter(double value) => '${value.toStringAsFixed(1)} cm';

  static String percent(double value) => '${value.toStringAsFixed(1)}%';
}
