import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum AIProvider { gemini, mistral, groq }

class AIService {
  AIService._();

  static Future<String> chat({
    required List<Map<String, String>> messages,
    AIProvider provider = AIProvider.gemini,
    String? systemPrompt,
  }) async {
    try {
      switch (provider) {
        case AIProvider.gemini:
          return await _callGemini(messages, systemPrompt);
        case AIProvider.mistral:
          return await _callMistral(messages, systemPrompt);
        case AIProvider.groq:
          return await _callGroq(messages, systemPrompt);
      }
    } catch (e) {
      // Chaîne de fallback : Gemini → Mistral → Groq
      if (provider == AIProvider.gemini) {
        try {
          return await _callMistral(messages, systemPrompt);
        } catch (_) {
          return await _callGroq(messages, systemPrompt);
        }
      }
      rethrow;
    }
  }

  // ── Gemini ─────────────────────────────────────────────────────────────────

  static Future<String> _callGemini(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final apiKey = AppConfig.geminiApiKey;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final contents = <Map<String, dynamic>>[];

    if (systemPrompt != null) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': systemPrompt}
        ],
      });
      contents.add({
        'role': 'model',
        'parts': [
          {'text': 'Understood. I will follow these instructions.'}
        ],
      });
    }

    for (final msg in messages) {
      contents.add({
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': msg['content']}
        ],
      });
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    throw Exception('Gemini API error: ${response.statusCode}');
  }

  // ── Mistral ────────────────────────────────────────────────────────────────

  static Future<String> _callMistral(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final apiKey = AppConfig.mistralApiKey;
    const url = 'https://api.mistral.ai/v1/chat/completions';

    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'mistral-small-latest',
        'messages': allMessages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Mistral API error: ${response.statusCode}');
  }

  // ── Groq ───────────────────────────────────────────────────────────────────

  static Future<String> _callGroq(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final apiKey = AppConfig.groqApiKey;
    const url = 'https://api.groq.com/openai/v1/chat/completions';

    final allMessages = <Map<String, String>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages);

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama3-70b-8192',
        'messages': allMessages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq API error: ${response.statusCode}');
  }

  // ── System prompt ──────────────────────────────────────────────────────────

  static const String scholarshipSystemPrompt = '''
You are Fly Assistant, an expert AI scholarship advisor helping African students access global academic opportunities.

You help students with:
- Finding and evaluating scholarships
- Writing compelling motivation letters and SOPs
- CV review and improvement
- Interview preparation
- Application strategy and checklist management

Always be encouraging, specific, and actionable. Respond in clear, concise English. Format lists with bullet points where appropriate.
''';
}