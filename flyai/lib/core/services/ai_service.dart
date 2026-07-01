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

  // ── Gemini ────────────────────────────────────────────────────────────────

  static Future<String> _callGemini(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    final apiKey = AppConfig.geminiApiKey;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final contents = <Map<String, dynamic>>[];

    if (systemPrompt != null) {
      contents
        ..add({'role': 'user', 'parts': [{'text': systemPrompt}]})
        ..add({'role': 'model', 'parts': [{'text': 'Understood.'}]});
    }

    for (final msg in messages) {
      contents.add({
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': msg['content']}],
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

  // ── Mistral ───────────────────────────────────────────────────────────────

  static Future<String> _callMistral(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    const url = 'https://api.mistral.ai/v1/chat/completions';
    final allMessages = [
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.mistralApiKey}',
      },
      body: jsonEncode({'model': 'mistral-small-latest', 'messages': allMessages}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Mistral API error: ${response.statusCode}');
  }

  // ── Groq ──────────────────────────────────────────────────────────────────

  static Future<String> _callGroq(
    List<Map<String, String>> messages,
    String? systemPrompt,
  ) async {
    const url = 'https://api.groq.com/openai/v1/chat/completions';
    final allMessages = [
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
      },
      body: jsonEncode({'model': 'llama3-70b-8192', 'messages': allMessages}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq API error: ${response.statusCode}');
  }

  // ── Gemini RAG Chat ───────────────────────────────────────────────────────

  static Future<String> chatWithRAG({
    required List<Map<String, String>> messages,
    String? cvBase64,
    String? scholarshipsContext,
    String? systemPrompt,
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final contents = <Map<String, dynamic>>[];

    // Add system prompt first
    if (systemPrompt != null) {
      contents
        ..add({'role': 'user', 'parts': [{'text': systemPrompt}]})
        ..add({'role': 'model', 'parts': [{'text': 'Understood. I will act as Fly Assistant.'}]});
    }

    // Add CV + matching scholarships context
    final contextParts = <Map<String, dynamic>>[];
    
    if (cvBase64 != null) {
      contextParts.add({
        'inlineData': {
          'mimeType': 'application/pdf',
          'data': cvBase64,
        }
      });
    }

    String contextText = '';
    if (scholarshipsContext != null) {
      contextText += 'Here is the list of available scholarships in our database:\n$scholarshipsContext\n\n';
    }
    if (cvBase64 != null) {
      contextText += 'I have attached the student\'s CV (PDF) for your analysis. Review the CV and match it against the scholarships.\n';
    }

    if (contextText.isNotEmpty) {
      contextParts.add({'text': contextText});
      contents.add({
        'role': 'user',
        'parts': contextParts,
      });
      contents.add({
        'role': 'model',
        'parts': [{'text': 'Thank you for providing the CV and scholarship context. I am ready to assist the student.'}]});
    }

    // Add conversation history
    for (final msg in messages) {
      contents.add({
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': msg['content']}],
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
    throw Exception('Gemini RAG API error: ${response.statusCode}');
  }

  // ── System prompt ─────────────────────────────────────────────────────────

  static const String scholarshipSystemPrompt = '''
You are Fly Assistant, an expert AI scholarship advisor helping students access global academic opportunities.

You help students with:
- Finding and matching scholarships based on their profile and CV
- Writing compelling, highly personalized motivation letters and SOPs matching their qualifications
- In-depth CV review, critiques, and specific updates
- Interview preparation coaching
- Checklist management

When writing a motivation letter or SOP, format it professionally as a standard letter (date, sender, recipient, subject, greeting, body, sign-off).
Adapt your response language to match the student's query language (e.g. write in French if asked in French).
Always be professional, specific, encouraging, and highly actionable. Avoid emojis in your responses.
''';
}