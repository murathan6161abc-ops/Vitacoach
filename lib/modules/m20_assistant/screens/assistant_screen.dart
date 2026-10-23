import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/speak_button.dart';
import '../../m11_access/providers/access_provider.dart';
import '../services/assistant_engine.dart';
import '../services/assistant_loader.dart';

class _Message {
  final bool fromUser;
  final String text;
  final AssistantReply? reply;
  _Message.user(this.text) : fromUser = true, reply = null;
  _Message.assistant(AssistantReply r)
    : fromUser = false,
      text = r.text,
      reply = r;
}

class AssistantScreen extends StatefulWidget {
  /// Ana sayfadan yazılarak gelinirse ilk soru.
  final String? initialQuestion;
  const AssistantScreen({super.key, this.initialQuestion});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  AssistantEngine? _engine;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final engine = await AssistantLoader.load();
      if (!mounted) return;
      setState(() {
        _engine = engine;
        _messages.add(_Message.assistant(engine.greeting()));
      });
      final q = widget.initialQuestion?.trim();
      if (q != null && q.isNotEmpty) _send(q);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Asistan yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final engine = _engine;
    final trimmed = text.trim();
    if (engine == null || trimmed.isEmpty) return;
    setState(() {
      _messages.add(_Message.user(trimmed));
      _messages.add(_Message.assistant(engine.respond(trimmed)));
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runAction(AssistantAction action) async {
    switch (action.type) {
      case AssistantActionType.call:
        final ok = await AccessProvider().callNumber(action.value);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Arama başlatılamadı. Lütfen ${action.value} numarasını elle arayın.',
              ),
            ),
          );
        }
      case AssistantActionType.route:
        await context.push(action.value);
        // Kullanıcı veri eklemiş olabilir: cevaplar güncel verilerle verilsin.
        final engine = _engine;
        if (engine != null) {
          engine.context = await AssistantLoader.loadContext();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastReply = _messages
        .lastWhere((m) => !m.fromUser, orElse: () => _Message.user(''))
        .reply;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Sağlık Asistanı'),
            Text(
              'Çevrimdışı · kural tabanlı · tanı koymaz',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loadError != null
                  ? Center(child: Text(_loadError!))
                  : _engine == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i], i),
                    ),
            ),
            if (lastReply != null && lastReply.quickReplies.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final q in lastReply.quickReplies)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q),
                          onPressed: () => _send(q),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Belirtinizi veya sorunuzu yazın…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Gönder',
                    onPressed: () => _send(_controller.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Message m, int index) {
    final maxWidth = MediaQuery.of(context).size.width * 0.82;
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            m.text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      );
    }
    final reply = m.reply!;
    final urgent = reply.urgent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
        decoration: BoxDecoration(
          color: urgent
              ? AppColors.danger.withValues(alpha: 0.08)
              : AppColors.surface,
          border: Border.all(
            color: urgent ? AppColors.danger : AppColors.cardBorder,
            width: urgent ? 1.5 : 1,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reply.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                SpeakButton(text: reply.text, id: 'assistant-$index'),
              ],
            ),
            if (reply.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final a in reply.actions)
                      a.type == AssistantActionType.call
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              onPressed: () => _runAction(a),
                              icon: const Icon(Icons.call, size: 18),
                              label: Text(a.label),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _runAction(a),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: Text(a.label),
                            ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
