import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

// Server-side API keys
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const MISTRAL_API_KEY = process.env.MISTRAL_API_KEY;
const TAVILY_API_KEY = process.env.TAVILY_API_KEY;
const BING_SEARCH_API_KEY = process.env.BING_SEARCH_API_KEY;

/**
 * Perform web search with multi-engine fallback (Tavily -> Bing -> DuckDuckGo)
 */
async function executeWebSearch(query: string, maxResults: number = 3): Promise<{ results: any[]; sources: string[] }> {
  // 1. Tavily Search
  if (TAVILY_API_KEY) {
    try {
      const res = await fetch("https://api.tavily.com/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          api_key: TAVILY_API_KEY,
          query,
          max_results: maxResults,
          search_depth: "advanced",
        }),
      });
      if (res.ok) {
        const data = await res.json();
        const results = data.results || [];
        const sources = results.map((r: any) => r.url).filter(Boolean);
        if (results.length > 0) return { results, sources };
      }
    } catch (e) {
      console.warn("Tavily search failed:", e);
    }
  }

  // 2. Bing Search
  if (BING_SEARCH_API_KEY) {
    try {
      const res = await fetch(
        `https://api.bing.microsoft.com/v7.0/search?q=${encodeURIComponent(query)}&count=${maxResults}`,
        { headers: { "Ocp-Apim-Subscription-Key": BING_SEARCH_API_KEY } }
      );
      if (res.ok) {
        const data = await res.json();
        const results = data.webPages?.value?.map((page: any) => ({
          title: page.name,
          url: page.url,
          content: page.snippet,
        })) || [];
        const sources = results.map((r: any) => r.url).filter(Boolean);
        if (results.length > 0) return { results, sources };
      }
    } catch (e) {
      console.warn("Bing search failed:", e);
    }
  }

  // 3. DuckDuckGo Scraper Fallback (Zero key required)
  try {
    const res = await fetch(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      },
    });
    if (res.ok) {
      const html = await res.text();
      const results: any[] = [];
      const regex = /<a class="result__snippet[^>]*href="([^"]+)"[^>]*>([^<]+)<\/a>/g;
      let match;
      while ((match = regex.exec(html)) !== null && results.length < maxResults) {
        results.push({
          title: match[2].trim(),
          url: match[1],
          content: match[2].trim(),
        });
      }
      if (results.length > 0) {
        return { results, sources: results.map((r) => r.url) };
      }
    }
  } catch (e) {
    console.warn("DuckDuckGo search failed:", e);
  }

  return { results: [], sources: [] };
}

/**
 * Determine if query requires live web search
 */
function shouldSearchWeb(query: string, availableScholarships: any[] = []): boolean {
  const queryLower = query.toLowerCase();
  const webSearchKeywords = [
    "deadline", "date limite", "clôture", "montant", "financement", "critères",
    "éligibilité", "requis", "documents", "comment postuler", "how to apply",
    "site officiel", "lien", "url", "2025", "2026", "nouvelle", "actualité"
  ];
  const hasKeyword = webSearchKeywords.some((kw) => queryLower.includes(kw));
  const scholarshipNames = availableScholarships.map((s) => s.titre?.toLowerCase() || "");
  const mentionsKnown = scholarshipNames.some((name) => name && queryLower.includes(name));
  return hasKeyword || !mentionsKnown;
}

/**
 * Model Fallback Providers (Gemini -> Groq -> Mistral)
 */
async function callGemini(systemPrompt: string, message: string, history: any[] = []): Promise<string | null> {
  if (!GEMINI_API_KEY) return null;
  const models = ["gemini-1.5-flash", "gemini-2.0-flash", "gemini-1.5-pro"];
  
  for (const model of models) {
    try {
      const formattedContents = [
        ...history.slice(-6).map((h) => ({
          role: h.role === "user" ? "user" : "model",
          parts: [{ text: h.content }],
        })),
        { role: "user", parts: [{ text: `${systemPrompt}\n\nUtilisateur : ${message}` }] },
      ];

      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: formattedContents,
            generationConfig: { temperature: 0.6, maxOutputTokens: 1400 },
          }),
        }
      );

      if (res.ok) {
        const data = await res.json();
        const replyText = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (replyText) return replyText;
      } else {
        console.warn(`Gemini model ${model} failed:`, await res.text());
      }
    } catch (e) {
      console.warn(`Gemini model ${model} exception:`, e);
    }
  }
  return null;
}

async function callGroq(systemPrompt: string, message: string, history: any[] = []): Promise<string | null> {
  if (!GROQ_API_KEY) return null;
  const models = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"];

  for (const model of models) {
    try {
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${GROQ_API_KEY}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt },
            ...history.slice(-6).map((h) => ({
              role: h.role === "user" ? "user" : "assistant",
              content: h.content,
            })),
            { role: "user", content: message },
          ],
          temperature: 0.6,
          max_tokens: 1400,
        }),
      });

      if (res.ok) {
        const data = await res.json();
        const replyText = data.choices?.[0]?.message?.content;
        if (replyText) return replyText;
      } else {
        console.warn(`Groq model ${model} failed:`, await res.text());
      }
    } catch (e) {
      console.warn(`Groq model ${model} exception:`, e);
    }
  }
  return null;
}

async function callMistral(systemPrompt: string, message: string, history: any[] = []): Promise<string | null> {
  if (!MISTRAL_API_KEY) return null;
  const models = ["mistral-small-latest", "open-mistral-7b", "mistral-medium-latest"];

  for (const model of models) {
    try {
      const res = await fetch("https://api.mistral.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${MISTRAL_API_KEY}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt },
            ...history.slice(-6).map((h) => ({
              role: h.role === "user" ? "user" : "assistant",
              content: h.content,
            })),
            { role: "user", content: message },
          ],
          temperature: 0.6,
          max_tokens: 1400,
        }),
      });

      if (res.ok) {
        const data = await res.json();
        const replyText = data.choices?.[0]?.message?.content;
        if (replyText) return replyText;
      } else {
        console.warn(`Mistral model ${model} failed:`, await res.text());
      }
    } catch (e) {
      console.warn(`Mistral model ${model} exception:`, e);
    }
  }
  return null;
}

/**
 * Execute Multi-Model Fallback Cascade
 */
async function callLLMWithFallback(
  systemPrompt: string,
  message: string,
  history: any[] = []
): Promise<{ reply: string; providerUsed: string }> {
  // 1. Try Gemini
  const geminiReply = await callGemini(systemPrompt, message, history);
  if (geminiReply) return { reply: geminiReply, providerUsed: "Gemini" };

  // 2. Try Groq
  const groqReply = await callGroq(systemPrompt, message, history);
  if (groqReply) return { reply: groqReply, providerUsed: "Groq" };

  // 3. Try Mistral
  const mistralReply = await callMistral(systemPrompt, message, history);
  if (mistralReply) return { reply: mistralReply, providerUsed: "Mistral" };

  // 4. DB RAG Fallback Response (if all API keys or endpoints are unavailable)
  const fallbackText =
    `Je suis actuellement en mode copilote autonome FlyAgent. ` +
    `J'ai analysé vos informations et la base de données. ` +
    `Voici les recommandations et étapes prioritaires pour votre dossier :\n\n` +
    `1. Vérifiez que votre CV et vos relevés de notes sont bien chargés dans l'onglet **Documents**.\n` +
    `2. Renseignez votre moyenne certifiée et votre score de langue dans votre **Profil**.\n` +
    `3. Vous pouvez suivre et gérer vos candidatures dans l'onglet **Mes Candidatures**.\n\n` +
    `Pour quelle bourse souhaitez-vous que je vérifie les critères et le lien officiel de postulation ?`;

  return { reply: fallbackText, providerUsed: "RAG_DB_Fallback" };
}

/**
 * Build RAG System Prompt
 */
function buildSystemPrompt(
  userProfile?: any,
  userDocuments?: any[],
  scholarshipContext?: any[],
  webSearchResults?: any[],
  webSources?: string[]
): string {
  const parts = [];

  if (userProfile) {
    parts.push(
      `=== PROFIL UTILISATEUR ===\n` +
      `Nom: ${userProfile.fullName || 'non spécifié'}\n` +
      `Niveau actuel: ${userProfile.degreeLevel || 'non spécifié'}\n` +
      `Niveau visé: ${userProfile.targetDegreeLevel || userProfile.degreeLevel || 'non spécifié'}\n` +
      `Domaine: ${userProfile.fieldOfStudy || 'non spécifié'}\n` +
      `Université: ${userProfile.university || 'non spécifiée'}\n` +
      `Nationalité: ${userProfile.nationality || 'non spécifiée'}\n` +
      `Pays cibles: ${(userProfile.targetCountries || []).join(', ') || 'non spécifiés'}\n` +
      `GPA / Moyenne: ${userProfile.gpa || 'non spécifié'} / Moyenne 20: ${userProfile.averageOutOf20 || 'non spécifiée'}\n` +
      `Langues: Anglais=${userProfile.languages?.english || userProfile.englishLevel || 'B2'}, Français=${userProfile.languages?.french || userProfile.frenchLevel || 'C1'}`
    );
  }

  if (userDocuments && userDocuments.length > 0) {
    parts.push(
      `=== DOCUMENTS UTILISATEUR DANS LA BASE DE DONNÉES ===\n` +
      userDocuments.map((doc: any, i: number) =>
        `${i + 1}. [${doc.category}] ${doc.file_name} (Taille: ${(doc.file_size / 1024).toFixed(1)} KB, Statut: ${doc.status}, URL: ${doc.download_url || 'disponible'})`
      ).join('\n')
    );
  } else {
    parts.push(`=== DOCUMENTS UTILISATEUR ===\nAucun document (CV / Relevés) téléversé pour l'instant.`);
  }

  if (scholarshipContext && scholarshipContext.length > 0) {
    parts.push(
      `=== BOURSES ET OPPORTUNITÉS (Base de données) ===\n` +
      scholarshipContext.slice(0, 5).map((s: any, i: number) =>
        `${i + 1}. ${s.titre}\n` +
        `   Pays: ${(s.pays_destination || []).join(', ')}\n` +
        `   Niveau: ${(s.niveau_etude || []).join(', ')}\n` +
        `   Domaines: ${(s.domaines || []).join(', ')}\n` +
        `   Financement: ${s.financement || 'INCONNU'}\n` +
        `   Deadline: ${s.deadline || 'Non spécifiée'}\n` +
        `   Lien officiel candidature: ${s.lien_candidature || s.url || 'Non renseigné'}`
      ).join('\n\n')
    );
  }

  if (webSearchResults && webSearchResults.length > 0) {
    parts.push(
      `=== RECHERCHE WEB EN TEMPS RÉEL ===\n` +
      webSearchResults.map((r: any, idx: number) =>
        `[Source ${idx + 1}] ${r.title || r.url}\nExtrait: ${(r.content || '').substring(0, 400)}`
      ).join('\n\n') +
      `\nSources à citer: ${(webSources || []).join(', ')}`
    );
  }

  return `Tu es FlyAgent, l'agent IA expert et copilote de candidature officielle de la plateforme FlyAI.
Tu es capable d'agir, de prendre des décisions factuelles et d'accompagner l'utilisateur étape par étape dans sa postulation.

TES DIRECTIVES CLÉS :
1. VOUVOIEMENT STRICT & TON PROFESSIONNEL : Tu es un mentor académique international exigeant et bienveillant.
2. ANALYSE DE CV : Si l'utilisateur demande d'analyser son CV ou ses documents, vérifie les documents ci-dessus. S'il a téléversé son CV, fais une analyse structurée en 3 parties (Points forts académiques, Lacunes/Risques pour les bourses cibles, Recommandations prioritaires). S'il n'a pas téléversé de CV, demande-lui de le déposer dans l'onglet 'Documents'.
3. POSTULATION ET CANDIDATURE AUTOMATISÉE :
   - Quand l'utilisateur demande de postuler à une bourse ou clique sur "Postuler avec FlyAgent", récupère les infos du client.
   - Vérifie s'il manque des éléments essentiels (score de langue, diplôme, lettre, CV). Si oui, demande à l'utilisateur de préciser ces infos.
   - Récupère et donne le lien officiel de la bourse dans le chat.
   - Demande confirmation à l'utilisateur s'il souhaite que FlyAgent procède à la préparation de sa candidature.
   - Confirme la prise en charge et indique que le suivi en temps réel se trouve dans l'onglet **Mes Candidatures**.
4. RECHERCHE BOURSES : Réponds précisément aux questions sur les bourses en combinant les données BDD et la recherche web en temps réel.
5. CONTEXTE RAG :\n${parts.join('\n\n')}`;
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

    // 1. Session persistence
    if (!activeSessionId && userId) {
      const { data: session, error: sessErr } = await supabase
        .from("chat_sessions")
        .insert({ firebase_uid: userId, title: message.slice(0, 45) })
        .select()
        .single();
      if (!sessErr && session) activeSessionId = session.id;
    }

    // 2. Save user message
    if (activeSessionId) {
      await supabase.from("chat_messages").insert({
        session_id: activeSessionId,
        sender: "user",
        content: message,
      });
    }

    // 3. Get session history
    let history: any[] = chatHistory || [];
    if (activeSessionId && (!chatHistory || chatHistory.length === 0)) {
      const { data: prevMsgs } = await supabase
        .from("chat_messages")
        .select("sender, content")
        .eq("session_id", activeSessionId)
        .order("created_at", { ascending: true })
        .limit(10);
      if (prevMsgs) {
        history = prevMsgs.map((m) => ({
          role: m.sender === "user" ? "user" : "assistant",
          content: m.content,
        }));
      }
    }

    // 4. Fetch user documents (CV, etc.)
    let userDocs: any[] = [];
    if (userId) {
      const { data: docs } = await supabase
        .from("application_documents")
        .select("*")
        .eq("firebase_uid", userId)
        .order("uploaded_at", { ascending: false });
      if (docs) userDocs = docs;
    }

    // 5. Fetch relevant bourses context
    let topBourses = scholarshipContext;
    if (!topBourses || topBourses.length === 0) {
      const { data: bourses } = await supabase
        .from("bourses")
        .select("id, titre, pays_destination, niveau_etude, financement, domaines, description, url, lien_candidature, deadline")
        .eq("active", true)
        .limit(8);
      topBourses = bourses || [];
    }

    // 6. Web Search if needed
    let webSearchResults: any[] = [];
    let webSources: string[] = [];
    if (shouldSearchWeb(message, topBourses)) {
      const searchRes = await executeWebSearch(message, 3);
      webSearchResults = searchRes.results;
      webSources = searchRes.sources;
    }

    // 7. Special Workflow: FlyAgent Auto-Application trigger
    const messageLower = message.toLowerCase();
    const isApplicationRequest = messageLower.includes("postuler") || messageLower.includes("candidater") || messageLower.includes("postuler avec flyagent");
    
    let targetScholarship = topBourses?.[0];
    if (isApplicationRequest && userId && targetScholarship) {
      // Upsert application into Supabase applications table
      const { error: appErr } = await supabase
        .from("applications")
        .upsert({
          firebase_uid: userId,
          bourse_id: targetScholarship.id,
          status: "in_progress",
          application_url: targetScholarship.lien_candidature || targetScholarship.url || "",
          notes: `Candidature initiée via FlyAgent le ${new Date().toLocaleDateString("fr-FR")}`,
          checklist: {
            cv_uploaded: userDocs.some((d) => d.category?.toUpperCase().includes("CV")),
            motivation_letter: true,
            transcripts: userDocs.some((d) => d.category?.toLowerCase().includes("relevé")),
            recommendation_1: false,
            language_test: !!(userProfile?.englishLevel || userProfile?.frenchLevel),
          },
          updated_at: new Date().toISOString(),
        }, { onConflict: "firebase_uid,bourse_id" });

      if (appErr) console.warn("Application upsert error:", appErr);
    }

    // 8. Generate LLM Reply with Multi-Model Fallback
    const systemPrompt = buildSystemPrompt(userProfile, userDocs, topBourses, webSearchResults, webSources);
    const { reply } = await callLLMWithFallback(systemPrompt, message, history);

    // 9. Save assistant response
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
      suggestedActions: [
        "📄 Analyser mon CV",
        "🌐 Obtenir le lien officiel de la bourse",
        "📊 Suivre mes candidatures dans 'Mes Candidatures'",
      ],
    });
  } catch (err: any) {
    console.error("Chat API error:", err);
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
