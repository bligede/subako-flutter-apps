import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/brand.dart';
import '../../core/security/permissions.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserProfile? user = ref.watch(authControllerProvider).value;
    final List<Site> sites = ref.watch(sitesProvider).value ?? const <Site>[];

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget content = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: user.name,
          subtitle: user.email,
          trailing: RoleBadge(role: user.role),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InfoRow(label: 'UID', value: user.uid),
              _InfoRow(
                label: 'Situs',
                value: sites.isEmpty
                    ? user.siteIds.join(', ')
                    : sites.map((Site s) => s.name).join(', '),
              ),
              _InfoRow(
                label: 'Izin',
                value: Permissions.of(user.role)
                    .map((String p) => p.split('.').last)
                    .join(', '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Menu',
          child: Column(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rule_outlined),
                title: const Text('Aturan & jadwal air'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/rules'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.assessment_outlined),
                title: const Text('Laporan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/reports'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('SUBAKO AI Assistant'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/ai'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Privasi & data',
          subtitle: 'Ringkasan kebijakan yang berlaku pada build ini.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '• Konteks ke Gemini dibatasi pada situs dan peran pengguna.',
              ),
              SizedBox(height: 4),
              Text('• Riwayat chat disimpan sementara di perangkat/sesi.'),
              SizedBox(height: 4),
              Text(
                '• Telemetri, alert, dan audit memiliki kebijakan retensi '
                'terpisah yang ditetapkan Product Owner.',
              ),
              SizedBox(height: 4),
              Text('• Tidak ada API key Gemini di dalam aplikasi.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Tentang aplikasi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InfoRow(label: 'Versi', value: AppConfig.buildLabel),
              _InfoRow(
                label: 'Backend',
                value: AppConfig.firebaseEnabled
                    ? 'Firebase (project ${AppConfig.firebaseProjectId})'
                    : 'Demo lokal (SIMULATION)',
              ),
              _InfoRow(label: 'Model AI', value: AppConfig.geminiModel),
              const SizedBox(height: 8),
              const Text(
                'SUBAKO by Mikiko Technology. Tradisi memutuskan, teknologi '
                'mengukur, SUBAKO mengeksekusi.',
                style: TextStyle(fontSize: 11, color: Brand.neutral),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (!context.mounted) {
              return;
            }
            context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: content,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Brand.neutral),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
