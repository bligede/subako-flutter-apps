import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/brand.dart';
import '../../core/utils/formatters.dart';
import '../../services/ai_assistant_service.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  static const List<String> _quickPrompts = <String>[
    'Bagaimana kondisi air saat ini?',
    'Jelaskan status pintu Gate-01.',
    'Apa arti alert yang muncul?',
    'Jelaskan aturan air yang sedang berlaku.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String prompt) async {
    final List<Device> devices =
        ref.read(devicesProvider).value ?? const <Device>[];
    final TelemetrySnapshot? telemetry = ref.read(telemetryProvider).value;
    final List<WaterRule> rules =
        ref.read(rulesProvider).value ?? const <WaterRule>[];
    final List<Alert> alerts =
        ref.read(alertsProvider).value ?? const <Alert>[];
    final List<Site> sites = ref.read(sitesProvider).value ?? const <Site>[];
    if (telemetry == null || sites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konteks belum tersedia. Coba lagi.')),
      );
      return;
    }

    setState(() => _sending = true);
    final AiContext aiContext = buildAuthorizedContext(
      site: sites.first,
      telemetry: telemetry,
      devices: devices,
      rules: rules,
      alerts: alerts,
    );
    await ref
        .read(chatControllerProvider.notifier)
        .send(prompt: prompt, context: aiContext);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    _controller.clear();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatMessage> messages = ref.watch(chatControllerProvider);
    final bool simulated = !AppConfig.firebaseEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SUBAKO AI Assistant'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Hapus percakapan',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus percakapan?'),
                  content: const Text('Riwayat sesi ini akan dibersihkan.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                ref.read(chatControllerProvider.notifier).clear();
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (simulated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Brand.warning.withValues(alpha: 0.14),
              child: const Text(
                'Mode simulasi: jawaban dihasilkan dari konteks demo, bukan '
                'Gemini. Build Firebase memakai Firebase AI Logic.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      const DisclaimerText(),
                      const SizedBox(height: 16),
                      Text(
                        'Tanyakan tentang data SUBAKO',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Asisten hanya menjelaskan data dan dokumen yang boleh '
                        'Anda akses. Ia tidak dapat menyetujui aturan, mengubah '
                        'alokasi, atau mengendalikan pintu air.',
                        style: TextStyle(fontSize: 12, color: Brand.neutral),
                      ),
                      const SizedBox(height: 16),
                      ..._quickPrompts.map(
                        (String prompt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton(
                            onPressed: () => _send(prompt),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(prompt),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + 1,
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: DisclaimerText(),
                        );
                      }
                      return _Bubble(message: messages[index - 1]);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: AppConfig.maxPromptChars,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pertanyaan…',
                        counterText: '',
                      ),
                      onSubmitted: _sending ? null : _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending
                        ? null
                        : () => _send(_controller.text.trim()),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Brand.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: user ? Brand.forestGreen : Brand.white,
          borderRadius: BorderRadius.circular(14),
          border: user
              ? null
              : Border.all(color: Brand.neutral.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(
              message.text,
              style: TextStyle(
                color: user ? Brand.white : Brand.darkText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (message.sources.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: message.sources
                    .map(
                      (String source) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Brand.softGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          source,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Brand.forestGreen,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              Formatters.time(message.createdAt),
              style: TextStyle(
                fontSize: 9,
                color: user ? Colors.white70 : Brand.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
