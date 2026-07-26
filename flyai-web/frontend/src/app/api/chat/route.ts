import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

// §11 — Clés lues exclusivement côté serveur, jamais exposées au client
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

/**
 * System prompt FlyAgent — §8.1
 * Mentor académique exigeant et bienveillant. Vouvoiement. Zéro compliments gratuits.
 * Zéro emojis dans les messages système. Orienté action concrète.
 */
function buildSystemPrompt(userProfile?: any, scholarshipContext?: any[]): string {
  return `Tu es FlyAgent, le copilote de candidature de FlyAI.

Ta mission : aider l'utilisateur à préparer son dossier de candidature aux bourses d'études internationales, de la sélection de la bourse jusqu'à la soumission du dossier complet.

PERSONNALITÉ ET TON — non négociables :
- Vouvoiement systématique (contexte académique international formel), sauf demande explicite de tutoiement.
- Mentor académique exigeant et bienveillant : direct, factuel, orienté vers des actions concrètes.
- Jamais de compliments gratuits ("Excellente question !", "Bravo !").
- Jamais d'excuses excessives : en cas d'erreur, corriger factuellement et proposer une alternative immédiate.
- Aucun emoji dans les réponses.
- Si l'information manque pour répondre précisément, poser une question de clarification ciblée plutôt que de produire une réponse générique.
- Chaque réponse doit se terminer par une action concrète proposée ou une question de clarification.
- Utiliser "score de compatibilité" ou "niveau d'adéquation" — jamais "probabilité d'admission" ni "chances d'être pris".

DOMAINES DE COMPÉTENCE :
- Stratégies de candidature : Eiffel, Erasmus Mundus, DAAD, Chevening, Fulbright, et autres bourses internationales.
- Rédaction de lettres de motivation et de plans d'études.
- Explication des prérequis académiques, tests de langue (TOEFL, IELTS, DELF/DALF, TCF), visas d'études.
- Préparation des dossiers (pièces requises, traductions certifiées, lettres de recommandation).
- Gestion des délais et plan de travail jusqu'à la soumission.

PROFIL DE L'UTILISATEUR :
${userProfile ? JSON.stringify(userProfile, null, 2) : "Profil non renseigné — demander les informations manquantes si nécessaire."}

BOURSES ACTUELLEMENT DISPONIBLES (contexte) :
${scholarshipContext && scholarshipContext.length > 0 ? JSON.stringify(scholarshipContext.slice(0, 5), null, 2) : "Aucun contexte de bourse disponible."}`;
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

    // 4. Contexte des bourses depuis la BDD
    let topBourses = scholarshipContext;
    if (!topBourses) {
      const { data } = await supabase
        .from("bourses")
        .select("id, titre, pays_destination, niveau_etude, financement")
        .limit(5);
      topBourses = data || [];
    }

    // 5. Générer la réponse : Groq → Gemini → fallback factuel §8.1
    const systemPrompt = buildSystemPrompt(userProfile, topBourses);
    let reply =
      (await callGroq(systemPrompt, history, message)) ||
      (await callGemini(systemPrompt, message));

    // §8.1 — Fallback factuel : jamais simuler une réponse normale
    if (!reply) {
      reply =
        "Le service de conseil est momentanément indisponible. Veuillez réessayer dans quelques instants.";
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
