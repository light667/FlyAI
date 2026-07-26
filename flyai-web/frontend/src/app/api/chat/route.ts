import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

// §11 — Clés lues exclusivement côté serveur, jamais exposées au client
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

/**
 * Determine if a query requires web search
 * This checks if the query is about scholarships, deadlines, or information that might not be in the database
 */
function shouldSearchWeb(query: string, availableScholarships: any[] = []): boolean {
  const queryLower = query.toLowerCase();

  // Keywords that indicate a need for web search
  const webSearchKeywords = [
    "deadline",
    "date limite",
    "date de clôture",
    "montant",
    "amount",
    "financement",
    "funding",
    "critères",
    "criteria",
    "conditions",
    "éligibilité",
    "eligibility",
    "requis",
    "required",
    "documents nécessaires",
    "required documents",
    "comment postuler",
    "how to apply",
    "application procedure",
    "procédure de candidature",
    "dernières informations",
    "latest information",
    "mettre à jour",
    "update",
    "nouveauté",
    "news",
    "actualité",
    "2026",
    "2025",
  ];

  // Check if query contains web search keywords
  const hasWebSearchKeyword = webSearchKeywords.some((kw) => queryLower.includes(kw));
  
  // Also check if query mentions a scholarship that might not be in our database
  const scholarshipNames = availableScholarships.map((s) => s.titre?.toLowerCase() || "");
  const mentionsKnownScholarship = scholarshipNames.some((name) => queryLower.includes(name));

  // Search if query contains keywords or mentions unknown scholarships
  return hasWebSearchKeyword || !mentionsKnownScholarship;
}

/**
 * System prompt FlyAgent — §8.1
 * Mentor académique exigeant et bienveillant. Vouvoiement. Zéro compliments gratuits.
 * Zéro emojis dans les messages système. Orienté action concrète.
 * Basé sur RAG (Retrieval-Augmented Generation) avec contexte bourse + recherche web
 */
function buildSystemPrompt(userProfile?: any, scholarshipContext?: any[], webSearchResults?: any[], webSources?: string[]): string {
  // Construire le contexte RAG (Retrieval-Augmented Generation)
  const ragContextParts = [];
  
  // 1. Contexte utilisateur pour personnalisation
  if (userProfile) {
    ragContextParts.push(`\n=== CONTEXTE UTILISATEUR (pour personnalisation) ===\n` +
      `Niveau actuel: ${userProfile.degreeLevel || 'non spécifié'}\n` +
      `Niveau visé: ${userProfile.targetDegreeLevel || userProfile.degreeLevel || 'non spécifié'}\n` +
      `Domaine: ${userProfile.fieldOfStudy || 'non spécifié'}\n` +
      `Nationalité: ${userProfile.nationality || 'non spécifiée'}\n` +
      `Pays cibles: ${(userProfile.targetCountries || []).join(', ') || 'non spécifiés'}\n` +
      `GPA: ${userProfile.gpa || 'non spécifié'}/4.0\n` +
      `Bio: ${userProfile.bio || 'non spécifiée'}`);
  }
  
  // 2. Contexte des bourses pour matching
  if (scholarshipContext && scholarshipContext.length > 0) {
    ragContextParts.push(`\n=== CONTEXTE BOURSES (pour matching) ===\n` +
      scholarshipContext.slice(0, 5).map((s: any, idx: number) => 
        `${idx + 1}. ${s.titre || 'Bourse non nommée'}\n` +
        `   Pays: ${(s.pays_destination || []).join(', ')}\n` +
        `   Niveau: ${(s.niveau_etude || []).join(', ')}\n` +
        `   Domaine: ${(s.domaines || []).join(', ')}\n` +
        `   Financement: ${s.financement || 'non spécifié'}\n` +
        `   Deadline: ${s.deadline || 'non spécifiée'}`
      ).join('\n\n'));
  }
  
  // 3. Résultats de recherche web pour informations actualisées
  const webContext = webSearchResults && webSearchResults.length > 0
    ? `\n\n=== CONTEXTE WEB (recherche en temps réel) ===\n` +
      webSearchResults.map((r: any, idx: number) => 
        `${idx + 1}. Source: ${r.url || r.title || 'Source inconnue'}\n` +
        `   Contenu: ${(r.content || r.snippet || '').substring(0, 500)}...`
      ).join('\n\n') +
      `\n\nSOURCES À CITER: ${webSources?.join(', ') || 'aucune'}`
    : '';

  return `Tu es FlyAgent, le copilote de candidature INTELLIGENT de FlyAI.
Tu fonctionnes avec un système de RAG (Retrieval-Augmented Generation) qui combine:
- Le profil de l'utilisateur
- Les bourses disponibles dans la base de données
- Les résultats de recherche web en temps réel

TA MISION: Aider l'utilisateur à préparer son dossier de candidature aux bourses d'études internationales.

INSTRUCTIONS PRINCIPALES:
1. TOUJOURS baser tes réponses sur les FAITS disponibles dans le contexte ci-dessous
2. Si tu as des résultats de recherche web, MENTIONNE EXPLICITEMENT la source avec "Selon [source]..."
3. Adapte tes conseils au PROFIL SPECIFIQUE de l'utilisateur
4. Si une bourse correspond particulièrement bien au profil, RECOMMANDE-LA explicitement
5. Si l'utilisateur pose une question spécifique sur une bourse, CHERCHE les détails dans le contexte

PERSONNALITÉ ET TON — non négociables :
- Vouvoiement systématique (contexte académique international formel)
- Mentor académique exigeant et bienveillant : direct, factuel, orienté ACTIONS CONCRÈTES
- Jamais de compliments gratuits, jamais d'excuses
- Aucun emoji, aucun jargon inutiles
- Chaque réponse doit se terminer par: une ACTION CONCRÈTE ou une QUESTION DE CLARIFICATION
- Utilise "score de compatibilité" ou "niveau d'adéquation" — jamais "probabilité d'admission"

DOMAINES DE COMPÉTENCE:
- Stratégies pour: Eiffel, Erasmus Mundus, DAAD, Chevening, Fulbright, etc.
- Rédaction: lettres de motivation, plans d'études, CV académique
- Explications: prérequis académiques, tests de langue (TOEFL, IELTS, DELF, TCF), visas
- Préparation dossiers: pièces requises, traductions, lettres de recommandation
- Gestion: délais, planning, suivi des candidatures

CONTEXTE RAG (Retrieval-Augmented Generation):${ragContextParts.join('')}${webContext}

INSTRUCTION FINALE: Basé-toi EXCLUSIVEMENT sur le contexte ci-dessus. Ne jamais inventer d'informations.`;
}

async function callGroq(
  systemPrompt: string,
  history: { role: string; content: string }[],
  message: string
): Promise<string | null> {
  if (!GROQ_API_KEY) return null;
  try {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "system", content: systemPrompt },
          ...history.map((h) => ({ role: h.role === "user" ? "user" : "assistant", content: h.content })),
          { role: "user", content: message },
        ],
        temperature: 0.6,
        max_tokens: 1200,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return data.choices?.[0]?.message?.content || null;
  } catch {
    return null;
  }
}

async function callGemini(
  systemPrompt: string,
  message: string
): Promise<string | null> {
  if (!GEMINI_API_KEY) return null;
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${systemPrompt}\n\nUtilisateur : ${message}` }] }],
          generationConfig: { temperature: 0.6, maxOutputTokens: 1200 },
        }),
      }
    );
    if (!res.ok) return null;
    const data = await res.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text || null;
  } catch {
    return null;
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const { userId, sessionId, message, userProfile, chatHistory, scholarshipContext } = body;

    if (!message) {
      return NextResponse.json({ error: "Message requis" }, { status: 400 });
    }

    let activeSessionId = sessionId;

    // 1. Créer une session si elle n'existe pas
    if (!activeSessionId && userId) {
      const { data: session, error: sessErr } = await supabase
        .from("chat_sessions")
        .insert({ firebase_uid: userId, title: message.slice(0, 50) })
        .select()
        .single();
      if (!sessErr && session) activeSessionId = session.id;
    }

    // 2. Sauvegarder le message utilisateur
    if (activeSessionId) {
      await supabase.from("chat_messages").insert({
        session_id: activeSessionId,
        sender: "user",
        content: message,
      });
    }

    // 3. Récupérer l'historique de la session en cours
    let history: { role: string; content: string }[] = chatHistory || [];
    if (activeSessionId && !chatHistory) {
      const { data: prevMsgs } = await supabase
        .from("chat_messages")
        .select("sender, content")
        .eq("session_id", activeSessionId)
        .order("created_at", { ascending: true })
        .limit(12);
      if (prevMsgs) {
        history = prevMsgs.map((m) => ({
          role: m.sender === "user" ? "user" : "assistant",
          content: m.content,
        }));
      }
    }

    // 4. Contexte des bourses depuis la BDD - RAG: Retrieval
    let topBourses = scholarshipContext;
    if (!topBourses) {
      // Essayer de trouver des bourses pertinentes basées sur la question
      // Si la question mentionne un pays, domaine, ou niveau spécifique
      let query = supabase.from("bourses").select("id, titre, pays_destination, niveau_etude, financement, domaines, description");
      
      // Filtrer par mots-clés de la question si pertinent
      const messageLower = message.toLowerCase();
      
      // Si la question mentionne un pays spécifique
      const countryKeywords = ['france', 'allemagne', 'canada', 'etats-unis', 'royaume-uni', 'togo', 'sénégal', 'maroc'];
      const matchedCountry = countryKeywords.find(kw => messageLower.includes(kw));
      if (matchedCountry) {
        query = query.contains('pays_destination', [matchedCountry]);
      }
      
      // Si la question mentionne un niveau
      const levelKeywords = ['licence', 'master', 'doctorat', 'bachelor', 'phd'];
      const matchedLevel = levelKeywords.find(kw => messageLower.includes(kw));
      if (matchedLevel) {
        query = query.contains('niveau_etude', [matchedLevel]);
      }
      
      // Limiter à 10 bourses pertinentes
      const { data } = await query.limit(10);
      topBourses = data || [];
    }

    // 5. Recherche web si nécessaire §4.2
    let webSearchResults: any[] = [];
    let webSources: string[] = [];
    const needsWebSearch = shouldSearchWeb(message, topBourses);

    if (needsWebSearch) {
      try {
        // Essayer Tavily en premier
        const tavilyResult = await searchTavily(message, 3);
        if (tavilyResult) {
          webSearchResults = tavilyResult.results;
          webSources = tavilyResult.results.map((r: any) => r.url).filter(Boolean);
        } else {
          // Essayer Bing si Tavily n'est pas disponible
          const bingResult = await searchBing(message, 3);
          if (bingResult) {
            webSearchResults = bingResult.results;
            webSources = bingResult.results.map((r: any) => r.url).filter(Boolean);
          }
        }
      } catch (searchError) {
        console.log("Web search failed, continuing without it:", searchError);
      }
    }

    // 5b. Construire le prompt avec les résultats de recherche
    const systemPrompt = buildSystemPrompt(userProfile, topBourses, webSearchResults, webSources);
    let reply =
      (await callGroq(systemPrompt, history, message)) ||
      (await callGemini(systemPrompt, message));

    // §8.1 — Fallback factuel : jamais simuler une réponse normale
    // Si aucun LLM n'est disponible, essayer de construire une réponse basée sur le contexte
    if (!reply) {
      const contextParts = [];
      
      // Ajouter le contexte des bourses
      if (scholarshipContext && scholarshipContext.length > 0) {
        contextParts.push(`Contexte des bourses disponibles: ${JSON.stringify(scholarshipContext.slice(0, 3).map(s => ({titre: s.titre, pays: s.pays_destination, niveau: s.niveau_etude})))}`);
      }
      
      // Ajouter le profil utilisateur
      if (userProfile) {
        contextParts.push(`Profil utilisateur: ${JSON.stringify({niveau: userProfile.degreeLevel, domaine: userProfile.fieldOfStudy, paysCible: userProfile.targetCountries})}`);
      }
      
      // Si on a du contexte, essayer de donner une réponse basée sur les données disponibles
      if (contextParts.length > 0) {
        reply = `Désolé, mon service de traitement avancé est temporairement indisponible. ` +
                `Cependant, je peux vous aider avec les informations disponibles dans notre base de données. ` +
                `Voici ce que je sais: ${contextParts.join('. ')}. ` +
                `Pour une réponse plus précise, pourriez-vous reformuler votre question ou réessayer dans quelques instants?`;
      } else {
        // Dernier recours: message minimal
        reply = "Désolé, je ne peux pas répondre pour le moment. Veuillez réessayer dans quelques instants ou reformuler votre question.";
      }
    }

    // 6. Sauvegarder la réponse de l'assistant
    if (activeSessionId) {
      await supabase.from("chat_messages").insert({
        session_id: activeSessionId,
        sender: "assistant",
        content: reply,
      });
    }

    return NextResponse.json({
      sessionId: activeSessionId,
      reply,
      suggestedActions: [],
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: "Une erreur technique est survenue. Veuillez réessayer." },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");
    const sessionId = searchParams.get("sessionId");

    if (sessionId) {
      const { data: messages, error } = await supabase
        .from("chat_messages")
        .select("*")
        .eq("session_id", sessionId)
        .order("created_at", { ascending: true });
      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ data: messages || [] });
    }

    if (userId) {
      const { data: sessions, error } = await supabase
        .from("chat_sessions")
        .select("*")
        .eq("firebase_uid", userId)
        .order("created_at", { ascending: false });
      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ data: sessions || [] });
    }

    return NextResponse.json({ error: "userId ou sessionId requis" }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
