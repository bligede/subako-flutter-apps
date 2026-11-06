import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_assistant_service.dart';
import '../../services/demo_repository.dart';
import '../../services/subako_repository.dart';
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

final Provider<String> activeSiteIdProvider = Provider<String>(
  (Ref ref) => 'site-sangeh',
);

/// Sesi pengguna.
class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final SubakoRepository repository = ref.watch(repositoryProvider);
    return repository.currentUser;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue<UserProfile?>.loading();
    state = await AsyncValue.guard(
      () =>
          ref.read(repositoryProvider).signIn(email: email, password: password),
    );
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

final StreamProvider<List<Device>> devicesProvider =
    StreamProvider<List<Device>>((Ref ref) {
      return ref
          .watch(repositoryProvider)
          .watchDevices(ref.watch(activeSiteIdProvider));
    });

final StreamProvider<TelemetrySnapshot> telemetryProvider =
    StreamProvider<TelemetrySnapshot>((Ref ref) {
      final List<Device> devices =
          ref.watch(devicesProvider).value ?? const <Device>[];
      final Device? measurement = devices
          .where((Device d) => d.kind == DeviceKind.measurement)
          .cast<Device?>()
          .firstWhere((Device? _) => true, orElse: () => null);
      return ref
          .watch(repositoryProvider)
          .watchTelemetry(measurement?.id ?? 'node-01');
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
      .where((Device d) => d.dataState != DataState.offline)
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
      lastGateEvents: const <String>[
        'Gate-01 posisi 35% • 09:12 WITA',
        'Gate-02 MANUAL fisik • 08:40 WITA',
      ],
      dataState: snapshot.dataState,
    ),
  );
});

/// Percakapan AI per sesi (demo, penyimpanan sementara).
class ChatController extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => <ChatMessage>[];

  Future<void> send({
    required String prompt,
    required AiContext context,
  }) async {
    final String trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }
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
    } on Object catch (error) {
      state = <ChatMessage>[
        ...pending,
        ChatMessage(
          id: 'e-${DateTime.now().microsecondsSinceEpoch}',
          isUser: false,
          text:
              'Asisten AI sedang tidak tersedia. Periksa koneksi lalu coba lagi. '
              'Detail: $error',
          createdAt: DateTime.now().toUtc(),
          isFallback: true,
        ),
      ];
    }
  }

  void clear() {
    state = <ChatMessage>[];
  }
}

final NotifierProvider<ChatController, List<ChatMessage>>
chatControllerProvider = NotifierProvider<ChatController, List<ChatMessage>>(
  ChatController.new,
);
