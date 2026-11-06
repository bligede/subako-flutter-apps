import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand.dart';
import '../../core/security/permissions.dart';
import '../../core/utils/formatters.dart';
import '../../services/subako_repository.dart';
import '../../shared/models/enums.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class RuleDetailScreen extends ConsumerWidget {
  const RuleDetailScreen({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WaterRule>> rules = ref.watch(rulesProvider);
    final UserProfile? user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail aturan')),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) =>
            Center(child: Text('Gagal memuat aturan: $error')),
        data: (List<WaterRule> items) {
          final WaterRule? rule = items
              .where((WaterRule r) => r.id == ruleId)
              .cast<WaterRule?>()
              .firstWhere((WaterRule? _) => true, orElse: () => null);
          if (rule == null) {
            return const EmptyState(message: 'Aturan tidak ditemukan.');
          }
          final bool canApprove =
              user != null && Permissions.canApproveRule(user.role);
          final bool canManage =
              user != null &&
              Permissions.can(user.role, Permissions.manageRules);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SectionCard(
                title: '${rule.tempek} • v${rule.version}',
                subtitle: rule.parumanReference,
                trailing: DataStateChip(state: DataState.simulation),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Row(label: 'Status', value: rule.status.label),
                    _Row(
                      label: 'Porsi alokasi',
                      value:
                          '${(rule.allocationShare * 100).toStringAsFixed(0)}%',
                    ),
                    _Row(label: 'Jadwal', value: rule.scheduleLabel),
                    _Row(
                      label: 'Berlaku',
                      value:
                          '${Formatters.date(rule.effectiveFrom)} – '
                          '${Formatters.date(rule.effectiveTo)}',
                    ),
                    _Row(
                      label: 'Diperbarui',
                      value: Formatters.dateTime(rule.updatedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Riwayat status',
                child: Column(
                  children: RuleStatus.values
                      .map((RuleStatus status) {
                        final bool reached =
                            RuleStatus.values.indexOf(status) <=
                            RuleStatus.values.indexOf(rule.status);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                reached
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: reached ? Brand.teal : Brand.neutral,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                status.label,
                                style: TextStyle(
                                  fontWeight: reached
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: reached
                                      ? Brand.darkText
                                      : Brand.neutral,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Tindakan',
                subtitle: 'Aktivitas ini tercatat pada audit trail.',
                child: Column(
                  children: <Widget>[
                    if (canManage && rule.status == RuleStatus.draft)
                      FilledButton(
                        onPressed: () => _run(
                          context,
                          ref,
                          () =>
                              ref.read(repositoryProvider).submitRule(rule.id),
                          'Aturan diajukan untuk persetujuan.',
                        ),
                        child: const Text('Ajukan persetujuan'),
                      ),
                    if (canApprove &&
                        (rule.status == RuleStatus.submitted ||
                            rule.status == RuleStatus.draft))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonal(
                          onPressed: () => _run(
                            context,
                            ref,
                            () => ref
                                .read(repositoryProvider)
                                .approveAndPublishRule(rule.id),
                            'Aturan disetujui dan diterbitkan.',
                          ),
                          child: const Text('Setujui & terbitkan'),
                        ),
                      ),
                    if (!canManage && !canApprove)
                      const Text(
                        'Peran Anda hanya dapat melihat aturan ini.',
                        style: TextStyle(fontSize: 12, color: Brand.neutral),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<WaterRule> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } on SubakoException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Brand.neutral, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
