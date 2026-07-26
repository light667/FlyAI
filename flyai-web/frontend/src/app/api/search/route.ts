import { NextRequest, NextResponse } from "next/server";

// Tavily API key for web search
const TAVILY_API_KEY = process.env.TAVILY_API_KEY;

/**
 * Perform web search using Tavily API
 * Tavily provides real-time web search results that can be cited in responses
 */
async function searchTavily(query: string, maxResults: number = 3): Promise<{ results: any[], rawText: string } | null> {
  if (!TAVILY_API_KEY) {
    console.warn("TAVILY_API_KEY not configured. Web search will not work.");
    return null;
  }

  try {
    const res = await fetch("https://api.tavily.com/search", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        api_key: TAVILY_API_KEY,
        query: query,
        max_results: maxResults,
        search_depth: "advanced",
        include_answer: false,
        include_raw_content: true,
      }),
    });

    if (!res.ok) {
      console.error("Tavily search error:", await res.text());
      return null;
    }

    const data = await res.json();
    return {
      results: data.results || [],
      rawText: data.raw_content || "",
    };
  } catch (error) {
    console.error("Tavily search failed:", error);
    return null;
  }
}

/**
 * Perform web search using a fallback method (Bing Search API)
 * This is a backup if Tavily is not available
 */
async function searchBing(query: string, maxResults: number = 3): Promise<{ results: any[], rawText: string } | null> {
  const BING_API_KEY = process.env.BING_SEARCH_API_KEY;
  if (!BING_API_KEY) {
    return null;
  }

  try {
    const res = await fetch(
      `https://api.bing.microsoft.com/v7.0/search?q=${encodeURIComponent(query)}&count=${maxResults}`,
      {
        headers: {
          "Ocp-Apim-Subscription-Key": BING_API_KEY,
        },
      }
    );

    if (!res.ok) {
      console.error("Bing search error:", await res.text());
      return null;
    }

    const data = await res.json();
    const results = data.webPages?.map((page: any) => ({
      title: page.name,
      url: page.url,
      snippet: page.snippet,
    })) || [];

    return {
      results,
      rawText: results.map((r: any) => `${r.title}: ${r.snippet}`).join("\n"),
    };
  } catch (error) {
    console.error("Bing search failed:", error);
    return null;
  }
}

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

  // If query mentions a specific scholarship name, check if it's in our database
  const scholarshipNames = availableScholarships.map((s) => s.titre?.toLowerCase() || "");
  const hasScholarshipMention = webSearchKeywords.some((kw) => queryLower.includes(kw));
  const mentionsKnownScholarship = scholarshipNames.some((name) => queryLower.includes(name));

  // Search if:
  // 1. Query contains web search keywords
  // 2. Query doesn't mention a known scholarship (might be a new one)
  // 3. Query explicitly asks for web search or latest info
  return hasScholarshipMention || !mentionsKnownScholarship;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { query, userId, scholarshipId } = body;

    if (!query) {
      return NextResponse.json(
        { error: "Query is required" },
        { status: 400 }
      );
    }

    // First, try Tavily
    let searchResult = await searchTavily(query);

    // If Tavily fails, try Bing
    if (!searchResult) {
      searchResult = await searchBing(query);
    }

    // If both fail, return an error
    if (!searchResult) {
      return NextResponse.json(
        {
          error: "Web search unavailable",
          message: "La recherche web n'est pas disponible. Veuillez vérifier que TAVILY_API_KEY ou BING_SEARCH_API_KEY est configuré.",
          suggestion: "Pour activer la recherche web, configurez TAVILY_API_KEY dans vos variables d'environnement.",
        },
        { status: 503 }
      );
    }

    return NextResponse.json({
      success: true,
      query,
      results: searchResult.results,
      rawContent: searchResult.rawText,
      sources: searchResult.results.map((r: any) => r.url).filter(Boolean),
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    console.error("Web search error:", err);
    return NextResponse.json(
      { error: err.message || "Web search failed" },
      { status: 500 }
    );
  }
}
