import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_assistant_service.dart';
import '../../services/demo_repository.dart';
import '../../services/subako_repository.dart';
import '../../core/domain/freshness.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';

SubakoRepository? _bootstrapRepository;

/// Dipanggil `main.dart` saat build Firebase diaktifkan.
void setBootstrapRepository(SubakoRepository repository) {
  _bootstrapRepository = repository;
}

/// Repository aktif: Firebase bila dikonfigurasi, jika tidak data simulasi.
final Provider<SubakoRepository> repositoryProvider =
    Provider<SubakoRepository>((Ref ref) {
      final SubakoRepository? bootstrap = _bootstrapRepository;
      if (bootstrap != null) {
        return bootstrap;
      }
      final DemoRepository repository = DemoRepository();
      ref.onDispose(repository.dispose);
      return repository;
    });

final Provider<AiAssistantService> aiAssistantProvider =
    Provider<AiAssistantService>((Ref ref) {
      return const DemoAiAssistantService();
    });

class ActiveSiteController extends Notifier<String> {
  String? _selected;
  String? _uid;
  @override
  String build() {
    final user = ref.watch(authControllerProvider).value;
    if (_uid != user?.uid) {
      _selected = null;
      _uid = user?.uid;
    }
    final sites = user?.siteIds ?? const <String>[];
    return sites.contains(_selected) ? _selected! : sites.firstOrNull ?? '';
  }

  void select(String siteId) {
    if (!(ref.read(authControllerProvider).value?.siteIds.contains(siteId) ??
        false)) {
      return;
    }
    _selected = siteId;
    state = siteId;
  }
}

final activeSiteIdProvider = NotifierProvider<ActiveSiteController, String>(
  ActiveSiteController.new,
);
final activeUserProvider = Provider<UserProfile?>(
  (ref) => ref
      .watch(authControllerProvider)
      .value
      ?.forSite(ref.watch(activeSiteIdProvider)),
);

/// Sesi pengguna.
class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final SubakoRepository repository = ref.watch(repositoryProvider);
    final initial = Completer<UserProfile?>();
    final subscription = repository.authStateChanges().listen(
      (user) {
        if (!initial.isCompleted) {
          initial.complete(user);
        } else {
          state = AsyncValue.data(user);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!initial.isCompleted) {
          initial.completeError(error, stack);
        } else {
          state = AsyncValue.error(error, stack);
        }
      },
    );
    ref.onDispose(subscription.cancel);
    return initial.future;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue<UserProfile?>.loading();
    state = await AsyncValue.guard(
      () =>
          ref.read(repositoryProvider).signIn(email: email, password: password),
    );
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
  }

  Future<void> signOut() async {
    await ref.read(repositoryProvider).signOut();
    state = const AsyncValue<UserProfile?>.data(null);
  }
}

final AsyncNotifierProvider<AuthController, UserProfile?>
authControllerProvider = AsyncNotifierProvider<AuthController, UserProfile?>(
  AuthController.new,
);

final StreamProvider<List<Site>> sitesProvider = StreamProvider<List<Site>>((
  Ref ref,
) {
  final String siteId = ref.watch(activeSiteIdProvider);
  return ref
      .watch(repositoryProvider)
      .watchSites()
      .map(
        (List<Site> sites) => sites
            .where((Site site) => site.id == siteId)
            .toList(growable: false),
      );
});

final allSitesProvider = StreamProvider<List<Site>>((ref) {
  ref.watch(
    authControllerProvider.select((value) => value.value?.siteIds.join(',')),
  );
  return ref.watch(repositoryProvider).watchSites();
});

final freshnessClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 5),
    (_) => DateTime.now().toUtc(),
  );
});
final StreamProvider<List<Device>> rawDevicesProvider =
    StreamProvider<List<Device>>((Ref ref) {
      return ref
          .watch(repositoryProvider)
          .watchDevices(ref.watch(activeSiteIdProvider));
    });

final devicesProvider = Provider<AsyncValue<List<Device>>>((ref) {
  final now = ref.watch(freshnessClockProvider).value ?? DateTime.now().toUtc();
  return ref
      .watch(rawDevicesProvider)
      .whenData(
        (devices) => devices
            .map(
              (d) => d.withState(
                d.fromCache
                    ? DataState.offline
                    : Freshness.evaluate(
                        d.lastSeen,
                        now: now,
                        simulated:
                            d.simulated || d.dataState == DataState.simulation,
                      ),
              ),
            )
            .toList(),
      );
});

final StreamProvider<TelemetrySnapshot> rawTelemetryProvider =
    StreamProvider<TelemetrySnapshot>((Ref ref) {
      final List<Device> devices =
          ref.watch(rawDevicesProvider).value ?? const <Device>[];
      final Device? measurement = devices
          .where((Device d) => d.kind == DeviceKind.measurement)
          .cast<Device?>()
          .firstWhere((Device? _) => true, orElse: () => null);
      if (measurement == null) {
        return ref.watch(rawDevicesProvider).isLoading
            ? const Stream.empty()
            : Stream.error(
                const SubakoException(
                  'Belum ada node pengukuran yang dapat dibaca pada site ini.',
                ),
              );
      }
      return ref.watch(repositoryProvider).watchTelemetry(measurement.id);
    });

final telemetryProvider = Provider<AsyncValue<TelemetrySnapshot>>((ref) {
  final now = ref.watch(freshnessClockProvider).value ?? DateTime.now().toUtc();
  return ref
      .watch(rawTelemetryProvider)
      .whenData(
        (s) => s.withState(
          s.fromCache
              ? DataState.offline
              : Freshness.evaluate(
                  s.recordedAt,
                  now: now,
                  simulated: s.simulated || s.dataState == DataState.simulation,
                ),
        ),
      );
});

final StreamProvider<List<Alert>> alertsProvider = StreamProvider<List<Alert>>((
  Ref ref,
) {
  return ref
      .watch(repositoryProvider)
      .watchAlerts(ref.watch(activeSiteIdProvider));
});

final StreamProvider<List<WaterRule>> rulesProvider =
    StreamProvider<List<WaterRule>>((Ref ref) {
      return ref
          .watch(repositoryProvider)
          .watchRules(ref.watch(activeSiteIdProvider));
    });

final StreamProvider<List<LedgerEntry>> ledgerProvider =
    StreamProvider<List<LedgerEntry>>((Ref ref) {
      return ref
          .watch(repositoryProvider)
          .watchLedger(ref.watch(activeSiteIdProvider));
    });

final StreamProvider<List<GateCommand>> commandsProvider =
    StreamProvider<List<GateCommand>>((Ref ref) {
      return ref
          .watch(repositoryProvider)
          .watchCommands(ref.watch(activeSiteIdProvider));
    });

/// Ringkasan dashboard yang menggabungkan beberapa stream.
final Provider<AsyncValue<DashboardSummary>>
dashboardProvider = Provider<AsyncValue<DashboardSummary>>((Ref ref) {
  final AsyncValue<List<Site>> sites = ref.watch(sitesProvider);
  final AsyncValue<List<Device>> devices = ref.watch(devicesProvider);
  final AsyncValue<TelemetrySnapshot> telemetry = ref.watch(telemetryProvider);
  final AsyncValue<List<Alert>> alerts = ref.watch(alertsProvider);

  if (sites.isLoading || devices.isLoading || telemetry.isLoading) {
    return const AsyncValue<DashboardSummary>.loading();
  }
  final Object? error = sites.error ?? devices.error ?? telemetry.error;
  if (error != null) {
    return AsyncValue<DashboardSummary>.error(
      error,
      sites.stackTrace ?? devices.stackTrace ?? StackTrace.current,
    );
  }
  final Site? site = sites.value?.isEmpty ?? true ? null : sites.value!.first;
  final List<Device> deviceList = devices.value ?? const <Device>[];
  final TelemetrySnapshot? snapshot = telemetry.value;
  if (site == null || snapshot == null) {
    return const AsyncValue<DashboardSummary>.loading();
  }
  final List<Device> online = deviceList
      .where(
        (Device d) =>
            d.dataState == DataState.live ||
            d.dataState == DataState.simulation,
      )
      .toList(growable: false);
  final double batteryAverage = deviceList.isEmpty
      ? 0
      : deviceList
                .where((Device d) => d.batteryPercent != null)
                .map((Device d) => d.batteryPercent!)
                .fold<double>(0, (double a, double b) => a + b) /
            deviceList.where((Device d) => d.batteryPercent != null).length;
  return AsyncValue<DashboardSummary>.data(
    DashboardSummary(
      site: site,
      onlineDevices: online.length,
      totalDevices: deviceList.length,
      averageBatteryPercent: batteryAverage.isNaN ? 0 : batteryAverage,
      telemetry: snapshot,
      activeAlerts: (alerts.value ?? const <Alert>[])
          .where((Alert a) => !a.acknowledged)
          .toList(growable: false),
      lastGateEvents: deviceList
          .where((d) => d.isGate)
          .take(3)
          .map(
            (d) =>
                '${d.name} • ${d.mode.label} • ${d.positionPercent?.toStringAsFixed(0) ?? "?"}% terlapor',
          )
          .toList(),
      dataState: snapshot.dataState,
    ),
  );
});

/// Percakapan AI per sesi (demo, penyimpanan sementara).
class ChatController extends Notifier<List<ChatMessage>> {
  int _generation = 0;
  @override
  List<ChatMessage> build() {
    ref.watch(authControllerProvider.select((value) => value.value?.uid));
    ref.watch(activeSiteIdProvider);
    _generation++;
    return <ChatMessage>[];
  }

  Future<void> send({
    required String prompt,
    required AiContext context,
  }) async {
    final String trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final int generation = _generation;
    final List<ChatMessage> pending = <ChatMessage>[
      ...state,
      ChatMessage(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        isUser: true,
        text: trimmed,
        createdAt: DateTime.now().toUtc(),
      ),
    ];
    state = pending;
    try {
      final AiReply reply = await ref
          .read(aiAssistantProvider)
          .ask(prompt: trimmed, context: context);
      if (!ref.mounted || generation != _generation) return;
      state = <ChatMessage>[
        ...pending,
        ChatMessage(
          id: 'a-${DateTime.now().microsecondsSinceEpoch}',
          isUser: false,
          text: reply.text,
          createdAt: DateTime.now().toUtc(),
          sources: reply.sources,
          isFallback: reply.isFallback,
        ),
      ];
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = <ChatMessage>[
        ...pending,
        ChatMessage(
          id: 'e-${DateTime.now().microsecondsSinceEpoch}',
          isUser: false,
          text:
              'Asisten AI sedang tidak tersedia. Periksa koneksi lalu coba lagi. '
              'Jawaban tidak dikirim ke perangkat dan tidak mengubah aturan.',
          createdAt: DateTime.now().toUtc(),
          isFallback: true,
        ),
      ];
    }
  }

  void clear() {
    _generation++;
    state = <ChatMessage>[];
  }
}

final NotifierProvider<ChatController, List<ChatMessage>>
chatControllerProvider = NotifierProvider<ChatController, List<ChatMessage>>(
  ChatController.new,
);
