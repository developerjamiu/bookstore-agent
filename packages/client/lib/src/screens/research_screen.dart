import 'package:flutter/material.dart';

import '../services/research_api.dart';
import '../widgets/answer_card.dart';
import '../widgets/tool_call_list.dart';

class ResearchScreen extends StatefulWidget {
  final ResearchApi api;

  const ResearchScreen({super.key, required this.api});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  ResearchResult? _result;
  String? _error;
  String? _lastQuestion;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _lastQuestion = question;
    });

    try {
      final result = await widget.api.ask(question);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _controller.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _error = null;
      _lastQuestion = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResult = _result != null || _error != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Music Store Agent',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask a question and a Genkit agent will explore the '
                  'database, run SQL queries, and answer.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !_loading,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: 'Which genre has the most tracks?',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _ask,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_loading && _lastQuestion != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Researching "$_lastQuestion"…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (_error != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                if (_result != null) ...[
                  AnswerCard(result: _result!),
                  const SizedBox(height: 12),
                  ToolCallList(toolCalls: _result!.toolCalls),
                ],
                if (hasResult && !_loading) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('New question'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
