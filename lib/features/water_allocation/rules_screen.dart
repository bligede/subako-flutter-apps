import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/brand.dart';
import '../../core/security/permissions.dart';
import '../../core/utils/formatters.dart';
import '../../services/subako_repository.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WaterRule>> rules = ref.watch(rulesProvider);
    final UserProfile? user = ref.watch(activeUserProvider);
    final bool canManage =
        user != null && Permissions.forUser(user, Permissions.manageRules);

    return Scaffold(
      appBar: AppBar(title: const Text('Aturan & jadwal air')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openDraftDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Draf aturan'),
            )
          : null,
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) =>
            Center(child: Text('Gagal memuat aturan: $error')),
        data: (List<WaterRule> items) {
          if (items.isEmpty) {
            return const EmptyState(
              message: 'Belum ada aturan air yang tercatat.',
              icon: Icons.rule_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Aturan disahkan melalui Paruman/Pekaseh. Versi yang sudah '
                'diterbitkan bersifat immutable; perubahan membuat versi baru.',
                style: TextStyle(fontSize: 12, color: Brand.neutral),
              ),
              const SizedBox(height: 12),
              ...items.map(
                (WaterRule rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RuleCard(rule: rule),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDraftDialog(BuildContext context, WidgetRef ref) async {
    final _DraftInput? input = await showModalBottomSheet<_DraftInput>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _DraftSheet(),
    );
    if (input == null) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .createDraftRule(
            siteId: ref.read(activeSiteIdProvider),
            tempek: input.tempek,
            allocationShare: input.share,
            scheduleLabel: input.schedule,
            parumanReference: input.reference,
            effectiveFrom: DateTime.now().toUtc(),
            effectiveTo: DateTime.now().toUtc().add(const Duration(days: 30)),
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draf aturan dibuat dan diajukan.')),
      );
    } on SubakoException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});

  final WaterRule rule;

  Color get _color => switch (rule.status) {
    RuleStatus.published => Brand.teal,
    RuleStatus.draft => Brand.neutral,
    RuleStatus.submitted => Brand.warning,
    RuleStatus.approved => Brand.teal,
    RuleStatus.expired || RuleStatus.revoked => Brand.critical,
  };

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '${rule.tempek} • v${rule.version}',
      subtitle: rule.parumanReference,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rule.status.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: 'Porsi alokasi',
                  value: '${(rule.allocationShare * 100).toStringAsFixed(0)}%',
                  state: DataState.simulation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(rule.scheduleLabel, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Berlaku ${Formatters.date(rule.effectiveFrom)} – '
            '${Formatters.date(rule.effectiveTo)}',
            style: const TextStyle(fontSize: 12, color: Brand.neutral),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/rules/${rule.id}'),
            child: const Text('Lihat aturan'),
          ),
        ],
      ),
    );
  }
}

class _DraftInput {
  const _DraftInput(this.tempek, this.share, this.schedule, this.reference);

  final String tempek;
  final double share;
  final String schedule;
  final String reference;
}

class _DraftSheet extends StatefulWidget {
  const _DraftSheet();

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  final TextEditingController _tempek = TextEditingController();
  final TextEditingController _schedule = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  double _share = 0.25;
  String? _error;

  @override
  void dispose() {
    _tempek.dispose();
    _schedule.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Draf aturan baru',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Draf belum berlaku sebelum diajukan dan disetujui Pekaseh.',
              style: TextStyle(fontSize: 12, color: Brand.neutral),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tempek,
              decoration: const InputDecoration(labelText: 'Tempek'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schedule,
              decoration: const InputDecoration(
                labelText: 'Jadwal',
                hintText: 'Senin–Kamis, 06:00–10:00 WITA',
              ),
            ),
            const SizedBox(height: 12),
            Text('Porsi alokasi: ${(_share * 100).toStringAsFixed(0)}%'),
            Slider(
              value: _share,
              onChanged: (double value) => setState(() => _share = value),
            ),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Referensi Paruman',
                hintText: 'Paruman 2026-11-02/I',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Brand.critical)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_tempek.text.trim().isEmpty ||
                    _schedule.text.trim().isEmpty ||
                    _reference.text.trim().isEmpty) {
                  setState(() => _error = 'Semua field wajib diisi.');
                  return;
                }
                Navigator.of(context).pop(
                  _DraftInput(
                    _tempek.text.trim(),
                    _share,
                    _schedule.text.trim(),
                    _reference.text.trim(),
                  ),
                );
              },
              child: const Text('Buat draf'),
            ),
          ],
        ),
      ),
    );
  }
}
