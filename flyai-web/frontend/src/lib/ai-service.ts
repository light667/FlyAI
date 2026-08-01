export interface AIResponsePayload {
  reply: string;
  sessionId?: string;
  suggestedActions?: string[];
  recommendedScholarshipIds?: string[];
}

/**
 * Generates a FlyAgent response by delegating to the secure server-side API route.
 * No API keys are held here — all secrets stay server-side only in /api/chat.
 * Multi-model fallback: Gemini -> Groq -> Mistral -> DB RAG.
 */
export async function generateFlyAgentResponse(
  userPrompt: string,
  chatHistory: { role: string; content: string }[] = [],
  userProfile?: any,
  scholarshipContext?: any[],
  userId?: string,
  sessionId?: string
): Promise<AIResponsePayload> {
  try {
    const res = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: userPrompt,
        chatHistory,
        userProfile,
        scholarshipContext,
        userId,
        sessionId,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.reply) {
        return {
          reply: data.reply,
          sessionId: data.sessionId,
          suggestedActions: data.suggestedActions,
          recommendedScholarshipIds: data.recommendedScholarshipIds,
        };
      }
    }
  } catch (e) {
    console.warn("FlyAgent API call failed:", e);
  }

  return {
    reply:
      "Le copilote FlyAgent est actuellement en train d'analyser vos informations. " +
      "Vous pouvez consulter vos candidatures en cours et les bourses recommandées dans votre tableau de bord.",
    suggestedActions: [
      "Consulter mes candidatures",
      "Découvrir les bourses recommandées",
      "Téléverser mon CV"
    ],
  };
}
