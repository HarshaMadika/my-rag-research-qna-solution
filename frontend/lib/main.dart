import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const RAGFrontendApp());
}

Future<Map<String, dynamic>> askAI(String query) async {
  final response = await http.post(
    Uri.parse('http://127.0.0.1:8000/ask'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'query': query}),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  } else {
    throw Exception('Failed to get response');
  }
}

class RAGFrontendApp extends StatelessWidget {
  const RAGFrontendApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Research Paper RAG',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      home: const RAGHomePage(),
    );
  }
}

class RAGHomePage extends StatefulWidget {
  const RAGHomePage({Key? key}) : super(key: key);

  @override
  State<RAGHomePage> createState() => _RAGHomePageState();
}

class _RAGHomePageState extends State<RAGHomePage> {
  final TextEditingController _queryController = TextEditingController();
  String? _answer;
  List<Map<String, dynamic>> _sources = [];
  bool _isLoading = false;
  String? _warningText;

  Future<void> _searchPapers() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _warningText = 'Please enter a research question or topic.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _warningText = null;
      _answer = null;
      _sources = [];
    });

    try {
      final data = await askAI(query);
      if (!mounted) return;

      setState(() {
        _answer = data['answer'];
        if (data['sources'] is List) {
          _sources = List<Map<String, dynamic>>.from(data['sources']);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _warningText =
            'Unable to reach backend. Check the API or emulator address.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF512DA8), Color(0xFF9575CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask your research assistant',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Type any question about papers, models, or findings and get the best answer from your RAG backend.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 22),
                Card(
                  margin: EdgeInsets.all(20),
                  elevation: 200,
                  shadowColor: Colors.black.withOpacity(0.95),
                  color: Colors.white.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _queryController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _searchPapers(),
                            decoration: InputDecoration(
                              hintText: 'Ask about research papers...',
                              border: InputBorder.none,
                              floatingLabelBehavior: theme
                                  .inputDecorationTheme.floatingLabelBehavior,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _searchPapers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF512DA8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 18,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_warningText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _warningText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.yellow[100],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _buildResultsList(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Contacting your RAG backend...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_answer == null && _sources.isEmpty) {
      return Center(
        child: Text(
          'Start with a question and the assistant will summarize research papers for you.',
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      key: ValueKey(_answer != null || _sources.isNotEmpty),
      children: [
        if (_answer != null) _buildAnswerCard(_answer!, theme),
        const SizedBox(height: 16),
        ..._sources.map((source) => _buildSourceCard(source, theme)).toList(),
      ],
    );
  }

  Widget _buildAnswerCard(String answer, ThemeData theme) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF512DA8), Color(0xFF9575CD)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🧠 Summary",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(Map<String, dynamic> source, ThemeData theme) {
    final randomDelay = Random().nextInt(200);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + randomDelay),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.85)
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source['title'] ?? 'No Title',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "ID: ${source['id'] ?? 'N/A'}",
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                source['abstract'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (source['authors'] != null)
                Text(
                  "Authors: ${source['authors']}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}
