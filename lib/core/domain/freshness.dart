import '../../shared/models/enums.dart';
import '../config/app_config.dart';

/// Menentukan status data dari waktu pengukuran terakhir.
class Freshness {
  const Freshness._();

  static DataState evaluate(
    DateTime recordedAt, {
    DateTime? now,
    Duration liveThreshold = AppConfig.liveThreshold,
    Duration staleThreshold = AppConfig.staleThreshold,
    bool simulated = false,
  }) {
    if (simulated) {
      return DataState.simulation;
    }
    final DateTime reference = (now ?? DateTime.now()).toUtc();
    final Duration age = reference.difference(recordedAt.toUtc());
    if (age.isNegative || age <= liveThreshold) {
      return DataState.live;
    }
    if (age <= staleThreshold) {
      return DataState.stale;
    }
    return DataState.offline;
  }

  static Duration age(DateTime recordedAt, {DateTime? now}) =>
      (now ?? DateTime.now()).toUtc().difference(recordedAt.toUtc());

  static bool isSafeForCommand(DataState state) => state == DataState.live;
}
