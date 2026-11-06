import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/brand.dart';
import '../../core/security/permissions.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';
import '../dashboard/dashboard_screen.dart';
import '../gates/gates_screen.dart';
import '../ledger/ledger_screen.dart';
import '../monitoring/monitoring_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final UserProfile? user = ref.watch(authControllerProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool canAcknowledge = Permissions.can(
      user.role,
      Permissions.acknowledgeAlert,
    );
    final int openAlerts = (ref.watch(alertsProvider).value ?? const <Alert>[])
        .where((Alert a) => !a.acknowledged)
        .length;

    final List<Widget> pages = <Widget>[
      const DashboardScreen(),
      const MonitoringScreen(),
      const GatesScreen(embedded: true),
      const LedgerScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const Icon(Icons.water_drop_outlined, color: Brand.forestGreen),
            const SizedBox(width: 8),
            const Text(
              AppConfig.appName,
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
            const SizedBox(width: 8),
            RoleBadge(role: user.role),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Alert',
            onPressed: () => context.push('/alerts'),
            icon: Badge.count(
              count: openAlerts,
              isLabelVisible: openAlerts > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'SUBAKO AI Assistant',
            onPressed: () => context.push('/ai'),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Laporan',
            onPressed: () => context.push('/reports'),
            icon: const Icon(Icons.assessment_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8E4)),
        ),
      ),
      body: Column(
        children: <Widget>[
          if (!AppConfig.firebaseEnabled) const SimulationBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      floatingActionButton: _index == 0 && canAcknowledge && openAlerts > 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/alerts'),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text('$openAlerts alert'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_outlined),
            selectedIcon: Icon(Icons.water),
            label: 'Monitoring',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_damage_outlined),
            selectedIcon: Icon(Icons.water_damage),
            label: 'Operasional',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Catatan Air',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
