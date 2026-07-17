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

  // ── Standard Gemini ───────────────────────────────────────────────────────

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

  // ── RAG Chat ──────────────────────────────────────────────────────────────

  static Future<String> chatWithRAG({
    required List<Map<String, String>> messages,
    String? cvBase64,
    String? scholarshipsContext,
    String? systemPrompt,
    String? attachedFileBase64,
    String? attachedFileMimeType,
  }) async {
    // Try Gemini first
    try {
      return await _chatWithRAGGemini(
        messages: messages,
        cvBase64: cvBase64,
        scholarshipsContext: scholarshipsContext,
        systemPrompt: systemPrompt,
        attachedFileBase64: attachedFileBase64,
        attachedFileMimeType: attachedFileMimeType,
      );
    } catch (_) {}

    // Fallback 1: Mistral
    try {
      final contextPreamble = _buildContextPreamble(scholarshipsContext, systemPrompt);
      return await _callMistral(messages, contextPreamble);
    } catch (_) {}

    // Fallback 2: Groq
    final contextPreamble = _buildContextPreamble(scholarshipsContext, systemPrompt);
    return await _callGroq(messages, contextPreamble);
  }

  static String _buildContextPreamble(String? scholarshipsContext, String? systemPrompt) {
    final parts = <String>[];
    if (systemPrompt != null) parts.add(systemPrompt);
    if (scholarshipsContext != null) {
      parts.add('Available scholarships:\n$scholarshipsContext');
    }
    return parts.join('\n\n');
  }

  static Future<String> _chatWithRAGGemini({
    required List<Map<String, String>> messages,
    String? cvBase64,
    String? scholarshipsContext,
    String? systemPrompt,
    String? attachedFileBase64,
    String? attachedFileMimeType,
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
    final contents = <Map<String, dynamic>>[];
    if (systemPrompt != null) {
      contents
        ..add({'role': 'user', 'parts': [{'text': systemPrompt}]})
        ..add({'role': 'model', 'parts': [{'text': 'Understood. I will act as Fly Assistant.'}]});
    }
    final contextParts = <Map<String, dynamic>>[];
    if (cvBase64 != null) {
      contextParts.add({'inlineData': {'mimeType': 'application/pdf', 'data': cvBase64}});
    }
    String contextText = '';
    if (scholarshipsContext != null) {
      contextText += 'Available scholarships:\n$scholarshipsContext\n\n';
    }
    if (cvBase64 != null) {
      contextText += 'Student CV attached for analysis.\n';
    }
    if (contextText.isNotEmpty) {
      contextParts.add({'text': contextText});
      contents.add({'role': 'user', 'parts': contextParts});
      contents.add({'role': 'model', 'parts': [{'text': 'Context received. Ready to assist.'}]});
    }

    // Add conversation history (all but the last message)
    final allMessages = messages;
    for (int i = 0; i < allMessages.length - 1; i++) {
      final msg = allMessages[i];
      contents.add({
        'role': msg['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': msg['content']}],
      });
    }

    // Build last user message with optional file attachment
    if (allMessages.isNotEmpty) {
      final lastMsg = allMessages.last;
      final lastParts = <Map<String, dynamic>>[];

      // Inject the user-uploaded file as inlineData BEFORE the text
      if (attachedFileBase64 != null && attachedFileMimeType != null) {
        lastParts.add({
          'inlineData': {
            'mimeType': attachedFileMimeType,
            'data': attachedFileBase64,
          }
        });
      }
      lastParts.add({'text': lastMsg['content'] ?? ''});

      contents.add({
        'role': lastMsg['role'] == 'assistant' ? 'model' : 'user',
        'parts': lastParts,
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
    throw Exception('Gemini RAG error: ${response.statusCode}');
  }

  // ── Coaching Agent (with Gemini Search Grounding) ─────────────────────────
  //
  // This is the core differentiator of Fly Agent vs ChatGPT / Claude:
  //   1. Personalized to the student profile
  //   2. Has full scholarship DB context
  //   3. Grounded search — retrieves live web info about the scholarship
  //   4. Structured coaching protocol with task generation
  //   5. Generates complete, ready-to-submit documents

  static Future<String> callCoachingAgent({
    required dynamic scholarship,   // ScholarshipModel
    required Map<String, dynamic>? profileJson,
    required List<Map<String, String>> messages,
    String? scholarshipsContext,
    bool generateTasks = false,
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    // Use gemini-1.5-flash with search grounding enabled
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final systemPrompt = _buildCoachingSystemPrompt(
      scholarship: scholarship,
      profileJson: profileJson,
      scholarshipsContext: scholarshipsContext,
      generateTasks: generateTasks,
    );

    final contents = <Map<String, dynamic>>[];

    // System context
    contents
      ..add({'role': 'user', 'parts': [{'text': systemPrompt}]})
      ..add({
        'role': 'model',
        'parts': [{'text': 'Compris. Je suis Fly Agent, ton coach dédié pour cette bourse. Je suis prêt à t\'accompagner vers le succès.'}]
      });

    // Handle the special briefing trigger
    bool isBriefingRequest = false;
    for (final msg in messages) {
      if ((msg['content'] ?? '').startsWith('START_COACHING:')) {
        isBriefingRequest = true;
        contents.add({
          'role': 'user',
          'parts': [{'text': 'Présente-moi cette bourse de façon complète et structurée, puis demande-moi si je veux commencer le processus.'}],
        });
      } else {
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [{'text': msg['content']}],
        });
      }
    }

    // Build request body with Google Search Grounding tool
    final body = <String, dynamic>{
      'contents': contents,
      'tools': [
        {
          // Gemini Search Grounding — gives the model live web access
          // to find up-to-date scholarship requirements, deadlines, etc.
          'google_search_retrieval': {
            'dynamic_retrieval_config': {
              'mode': 'MODE_DYNAMIC',
              'dynamic_threshold': 0.3, // Trigger search for specific queries
            }
          }
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('No candidates in response');
        }
        final parts = candidates[0]['content']['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          throw Exception('No parts in candidate');
        }
        // Concatenate all text parts (search grounding may return multiple)
        final text = parts
            .where((p) => p['text'] != null)
            .map((p) => p['text'] as String)
            .join('\n');
        return text;
      }
      // Fallback: retry without search grounding if 400
      if (response.statusCode == 400) {
        return await _callCoachingAgentNoSearch(
          contents: contents,
          apiKey: apiKey,
        );
      }
      throw Exception('Coaching agent error: ${response.statusCode} — ${response.body.substring(0, 200)}');
    } catch (e) {
      // Ultimate fallback to Mistral
      final flatMessages = messages
          .where((m) => !m['content']!.startsWith('START_COACHING:'))
          .toList();
      if (flatMessages.isEmpty) {
        flatMessages.add({'role': 'user', 'content': 'Présente cette bourse et mon plan de candidature.'});
      }
      return _callMistral(
        flatMessages.map((m) => {'role': m['role']!, 'content': m['content']!}).toList(),
        _buildCoachingSystemPrompt(scholarship: scholarship, profileJson: profileJson),
      );
    }
  }

  static Future<String> _callCoachingAgentNoSearch({
    required List<Map<String, dynamic>> contents,
    required String apiKey,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    throw Exception('Gemini fallback error: ${response.statusCode}');
  }

  static String _buildCoachingSystemPrompt({
    required dynamic scholarship,
    required Map<String, dynamic>? profileJson,
    String? scholarshipsContext,
    bool generateTasks = false,
  }) {
    final name = scholarship?.title ?? 'cette bourse';
    final country = scholarship?.country ?? '';
    final university = scholarship?.university ?? '';
    final degree = scholarship?.degreeLevel ?? '';
    final funding = scholarship?.fundingType ?? '';
    final description = scholarship?.description ?? '';
    final requirements = (scholarship?.requirements as List?)?.join(', ') ?? '';
    final fields = (scholarship?.fields as List?)?.join(', ') ?? '';
    final deadline = scholarship?.deadline?.toString().substring(0, 10) ?? 'À vérifier';
    final appUrl = scholarship?.applicationUrl ?? '';

    final studentName = profileJson?['full_name'] ?? 'l\'étudiant(e)';
    final studentCountry = profileJson?['country'] ?? '';
    final studentNationality = profileJson?['nationality'] ?? '';
    final studentLevel = profileJson?['education_level'] ?? '';
    final studentField = profileJson?['field_of_study'] ?? '';
    final studentUniversity = profileJson?['university'] ?? '';
    final studentGpa = profileJson?['gpa']?.toString() ?? '';
    final studentGoals = profileJson?['academic_goals'] ?? '';
    final englishLevel = profileJson?['english_level'] ?? '';
    final frenchLevel = profileJson?['french_level'] ?? '';

    final taskInstruction = generateTasks ? '''

⚠️ IMPORTANT: L'étudiant vient de confirmer vouloir candidater. Génère maintenant un plan d'action COMPLET.
Inclus la liste de tâches au format exact suivant (remplace le contenu par les vraies exigences de cette bourse) :

<tasks>
[
  {"id": "1", "title": "CV actualisé", "category": "document", "description": "Mettre à jour et adapter ton CV aux critères de la bourse"},
  {"id": "2", "title": "Lettre de motivation", "category": "document", "description": "Rédiger une lettre ciblée pour cette bourse"},
  {"id": "3", "title": "Relevé de notes", "category": "document", "description": "Obtenir ton relevé de notes officiel et traduit si nécessaire"},
  {"id": "4", "title": "Lettres de recommandation", "category": "document", "description": "Obtenir 2-3 lettres de professeurs ou superviseurs"},
  {"id": "5", "title": "Diplôme / Attestation", "category": "document", "description": "Fournir une copie certifiée de ton diplôme le plus élevé"},
  {"id": "6", "title": "Passeport valide", "category": "document", "description": "Vérifier que ton passeport est valide pour toute la durée des études"},
  {"id": "7", "title": "Certificat de langue", "category": "test", "description": "Fournir un test de langue (IELTS, TOEFL, DELF, etc.) si requis"},
  {"id": "8", "title": "Dossier de candidature en ligne", "category": "online", "description": "Remplir le formulaire officiel de candidature sur le site de la bourse"}
]
</tasks>

Après la liste, explique chaque étape et comment tu vas aider l'étudiant pour chacune.
''' : '';

    return '''
Tu es Fly Agent — le coach IA spécialisé en bourses académiques de Fly AI.

Tu n'es PAS un assistant IA généraliste. Tu es un EXPERT ABSOLU en candidatures aux bourses internationales.
Ta mission : faire obtenir la bourse "$name" à $studentName.

═══════════════════════════════════════════════════════
BOURSE CIBLE
═══════════════════════════════════════════════════════
Nom : $name
Université : $university
Pays : $country
Niveau : $degree
Financement : $funding
Deadline : $deadline
Domaines : $fields
Documents requis : $requirements
Description : $description
Lien candidature : $appUrl

═══════════════════════════════════════════════════════
PROFIL DE L'ÉTUDIANT
═══════════════════════════════════════════════════════
Nom : $studentName
Pays : $studentCountry
Nationalité : $studentNationality
Niveau d'études : $studentLevel
Filière : $studentField
Université : $studentUniversity
GPA / Moyenne : $studentGpa
Anglais : $englishLevel
Français : $frenchLevel
Objectifs : $studentGoals

═══════════════════════════════════════════════════════
AUTRES BOURSES DISPONIBLES DANS NOTRE BASE
═══════════════════════════════════════════════════════
${scholarshipsContext ?? 'Non disponible'}

═══════════════════════════════════════════════════════
TON PROTOCOLE DE COACHING
═══════════════════════════════════════════════════════
Phase 1 — BRIEFING : Présente la bourse de façon claire et complète. Informe l'étudiant de TOUT ce qu'il doit savoir.
Phase 2 — CONFIRMATION : Demande si l'étudiant est prêt à commencer.
Phase 3 — PLANNING : Génère un plan d'action et une liste de tâches complète.
Phase 4 — EXÉCUTION : Guide l'étudiant tâche par tâche. Si demandé, rédige les documents complets (lettre de motivation, SOP, etc.) entièrement personnalisés à son profil.
Phase 5 — SOUMISSION : Fournis le lien de candidature et fais une révision finale.

RÈGLES IMPORTANTES :
- Utilise TOUJOURS la langue de l'étudiant (français si il écrit en français).
- Sois SPÉCIFIQUE, pas généraliste. Adapte chaque réponse à CE profil et CETTE bourse.
- Quand tu rédiges une lettre de motivation : génère une lettre COMPLÈTE, prête à soumettre, pas un template.
- Si tu as besoin d'informations en ligne sur cette bourse, recherche-les (tu as accès au web).
- Pour les étudiants qui n'ont jamais postulé à une bourse : explique chaque étape comme si c'était la première fois.
- Tu es meilleur que ChatGPT et Claude pour les bourses car tu connais cette bourse spécifiquement et le profil de cet étudiant.
$taskInstruction
''';
  }

  // ── Legacy system prompt ──────────────────────────────────────────────────

  static const String scholarshipSystemPrompt = '''
You are Fly Assistant, an expert AI scholarship advisor helping students access global academic opportunities.
- Finding and matching scholarships based on their profile and CV
- Writing compelling motivation letters and SOPs
- CV review and critique
- Interview preparation
- Application checklist management

When writing a document, generate a complete, ready-to-use version — not a template.
Respond in the language the student uses. Always be specific, encouraging, and actionable.
''';
}
