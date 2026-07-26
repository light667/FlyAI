export interface AIResponsePayload {
  reply: string;
  suggestedActions?: string[];
  recommendedScholarshipIds?: string[];
}

/**
 * Generates a FlyAgent response by delegating to the secure server-side API route.
 * No API keys are held here — all secrets stay server-side only in /api/chat.
 * §11 compliance: zero secrets exposed to the client.
 */
export async function generateFlyAgentResponse(
  userPrompt: string,
  chatHistory: { role: string; content: string }[] = [],
  userProfile?: any,
  scholarshipContext?: any[]
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
      }),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.reply) {
        return {
          reply: data.reply,
          suggestedActions: data.suggestedActions,
          recommendedScholarshipIds: data.recommendedScholarshipIds,
        };
      }
    }
  } catch (e) {
    console.warn("FlyAgent API call failed:", e);
  }

  // §8.1 — Fallback factuel : indiquer l'indisponibilité réelle, jamais simuler une réponse
  return {
    reply:
      "Le service de conseil est momentanément indisponible. Veuillez réessayer dans quelques instants. " +
      "En attendant, vous pouvez consulter les descriptions détaillées des bourses et les guides dans l'onglet 'Découvrir'.",
    suggestedActions: [
      "Consulter les bourses recommandées",
      "Lire les descriptions détaillées des bourses",
      "Vérifier les critères d'éligibilité"
    ],
  };
}
