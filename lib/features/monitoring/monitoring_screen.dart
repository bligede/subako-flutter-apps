import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  final List<double> _upstream = <double>[];
  final List<double> _downstream = <double>[];
  final List<double> _flow = <double>[];
  DateTime? _lastRecordedAt;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeSiteIdProvider, (previous, next) {
      if (previous != next) {
        _upstream.clear();
        _downstream.clear();
        _flow.clear();
        _lastRecordedAt = null;
      }
    });
    ref.listen<AsyncValue<TelemetrySnapshot>>(telemetryProvider, (
      AsyncValue<TelemetrySnapshot>? previous,
      AsyncValue<TelemetrySnapshot> next,
    ) {
      final TelemetrySnapshot? snapshot = next.value;
      if (snapshot == null) {
        return;
      }
      final bool isNew = _lastRecordedAt != snapshot.recordedAt;
      if (!isNew) {
        return;
      }
      setState(() {
        _lastRecordedAt = snapshot.recordedAt;
        _upstream.add(snapshot.upstreamCm);
        _downstream.add(snapshot.downstreamCm);
        _flow.add(snapshot.flowLiterPerSecond);
        while (_upstream.length > 12) {
          _upstream.removeAt(0);
        }
        while (_downstream.length > 12) {
          _downstream.removeAt(0);
        }
        while (_flow.length > 12) {
          _flow.removeAt(0);
        }
      });
    });

    final AsyncValue<TelemetrySnapshot> telemetry = ref.watch(
      telemetryProvider,
    );
    final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Ringkasan'),
              Tab(text: 'Perangkat'),
              Tab(text: 'Peta'),
            ],
          ),
          Expanded(
            child: telemetry.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace? stack) =>
                  Center(child: Text('Monitoring tidak tersedia: $error')),
              data: (TelemetrySnapshot snapshot) {
                return TabBarView(
                  children: <Widget>[
                    _buildOverview(context, snapshot),
                    _buildDevices(context, devices.value ?? const <Device>[]),
                    const _MapPlaceholder(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, TelemetrySnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: 'Level air',
          subtitle: '12 sampel terakhir di memori tampilan',
          trailing: DataStateChip(state: snapshot.dataState),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 190,
                child: _TrendChart(
                  series: <_Series>[
                    _Series('Hulu', _upstream, Brand.teal),
                    _Series('Hilir', _downstream, Brand.forestGreen),
                  ],
                  unit: 'cm',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MetricTile(
                      label: 'Hulu',
                      value: Formatters.centimeter(snapshot.upstreamCm),
                      caption: snapshot.quality,
                      state: snapshot.dataState,
                    ),
                  ),
                  Expanded(
                    child: MetricTile(
                      label: 'Hilir',
                      value: Formatters.centimeter(snapshot.downstreamCm),
                      caption: Formatters.dateTime(snapshot.recordedAt),
                      state: snapshot.dataState,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Debit',
          subtitle: 'Target hanya ditampilkan bila aturan aktif menetapkannya',
          trailing: DataStateChip(state: snapshot.dataState),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 170,
                child: _TrendChart(
                  series: <_Series>[_Series('Debit', _flow, Brand.teal)],
                  unit: 'L/detik',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${Formatters.literPerSecond(snapshot.flowLiterPerSecond)} • '
                'diukur ${Formatters.time(snapshot.recordedAt)} WITA',
                style: const TextStyle(fontSize: 12, color: Brand.neutral),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevices(BuildContext context, List<Device> devices) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (devices.isEmpty)
          const EmptyState(message: 'Belum ada perangkat pada situs ini.')
        else
          ...devices.map((Device device) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                title: device.name,
                subtitle:
                    '${device.kind.label} • ${device.firmware ?? 'firmware n/a'}',
                trailing: DataStateChip(state: device.dataState),
                child: Column(
                  children: <Widget>[
                    _HealthRow(
                      label: 'Baterai',
                      value: device.batteryPercent == null
                          ? 'tidak tersedia'
                          : Formatters.percent(device.batteryPercent!),
                      warning: (device.batteryPercent ?? 100) < 20,
                    ),
                    _HealthRow(
                      label: 'RSSI',
                      value: device.rssi == null
                          ? 'tidak tersedia'
                          : '${device.rssi} dBm',
                      warning: (device.rssi ?? -60) < -95,
                    ),
                    _HealthRow(
                      label: 'Uplink terakhir',
                      value: Formatters.relative(device.lastSeen),
                      warning: device.dataState == DataState.offline,
                    ),
                    _HealthRow(
                      label: 'Mode',
                      value: device.mode.label,
                      warning: device.mode == GateMode.fault,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.warning,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Brand.neutral)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warning ? Brand.critical : Brand.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.series, required this.unit});

  final List<_Series> series;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final List<double> all = series
        .expand((_Series s) => s.values)
        .toList(growable: false);
    if (all.isEmpty) {
      return const Center(child: Text('Menunggu sampel…'));
    }
    final double minValue = all.reduce(math.min);
    final double maxValue = all.reduce(math.max);
    final double padding = ((maxValue - minValue).abs() * 0.2).clamp(1, 10);

    return LineChart(
      LineChartData(
        minY: minValue - padding,
        maxY: maxValue + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double value) => FlLine(
            color: Brand.neutral.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: Brand.neutral),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: series
            .map((_Series item) {
              final List<FlSpot> spots = <FlSpot>[
                for (int i = 0; i < item.values.length; i++)
                  FlSpot(i.toDouble(), item.values[i]),
              ];
              return LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                barWidth: 2.4,
                color: item.color,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: item.color.withValues(alpha: 0.08),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _Series {
  const _Series(this.label, this.values, this.color);

  final String label;
  final List<double> values;
  final Color color;
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: 'Peta Subak',
          subtitle:
              'Placeholder — provider peta belum dipasang pada build ini. '
              'Titik koordinat diambil dari metadata perangkat.',
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              color: Brand.softGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Brand.neutral.withValues(alpha: 0.25)),
            ),
            child: Stack(
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: Brand.neutral,
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 36,
                  child: _MapMarker(
                    label: 'Gate-01',
                    color: Brand.teal,
                    icon: Icons.water_damage_outlined,
                  ),
                ),
                Positioned(
                  right: 32,
                  top: 110,
                  child: _MapMarker(
                    label: 'Gate-02',
                    color: Brand.warning,
                    icon: Icons.water_damage_outlined,
                  ),
                ),
                const Positioned(
                  left: 90,
                  bottom: 40,
                  child: _MapMarker(
                    label: 'Gateway',
                    color: Brand.forestGreen,
                    icon: Icons.router_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Catatan integrasi',
          child: Text(
            'Peta memakai abstraksi provider agar atribusi dan lisensi peta '
            'dapat dipilih sebelum rilis. Build simulasi tidak memuat batas '
            'situs resmi maupun koordinat lapangan sebenarnya.',
          ),
        ),
      ],
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Brand.white, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Brand.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: const TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
