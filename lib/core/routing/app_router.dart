import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/authentication/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/gates/gate_detail_screen.dart';
import '../../features/gates/gates_screen.dart';
import '../../features/ledger/ledger_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/water_allocation/rule_detail_screen.dart';
import '../../features/water_allocation/rules_screen.dart';
import '../../shared/providers/app_providers.dart';

/// Notifier agar GoRouter menghitung ulang redirect saat sesi berubah.
class AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final Provider<AuthRefreshNotifier> authRefreshProvider =
    Provider<AuthRefreshNotifier>((Ref ref) {
      final AuthRefreshNotifier notifier = AuthRefreshNotifier();
      ref.onDispose(notifier.dispose);
      return notifier;
    });

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final AuthRefreshNotifier refresh = ref.watch(authRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<dynamic> auth = ref.read(authControllerProvider);
      if (auth.isLoading) {
        return null;
      }
      final bool loggedIn = auth.value != null;
      final String location = state.matchedLocation;
      final bool isPublic =
          location == '/splash' ||
          location == '/login' ||
          location == '/onboarding';
      if (!loggedIn && !isPublic) {
        return '/login';
      }
      if (loggedIn && (location == '/login' || location == '/onboarding')) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const AppShell(),
        routes: <RouteBase>[
          GoRoute(
            path: 'gates/:gateId',
            builder: (_, GoRouterState state) =>
                GateDetailScreen(gateId: state.pathParameters['gateId']!),
          ),
          GoRoute(
            path: 'rules',
            builder: (_, _) => const RulesScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':ruleId',
                builder: (_, GoRouterState state) =>
                    RuleDetailScreen(ruleId: state.pathParameters['ruleId']!),
              ),
            ],
          ),
          GoRoute(path: 'ai', builder: (_, _) => const AiAssistantScreen()),
          GoRoute(path: 'alerts', builder: (_, _) => const AlertsScreen()),
          GoRoute(path: 'reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(path: 'gates', builder: (_, _) => const GatesScreen()),
          GoRoute(path: 'ledger', builder: (_, _) => const LedgerScreen()),
          GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: 'dashboard',
            builder: (_, _) => const DashboardScreen(),
          ),
        ],
      ),
    ],
  );
});
