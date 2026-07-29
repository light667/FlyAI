import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();

    const { userId, bourseId, direction, score, category } = body;

    if (!userId || !bourseId || !direction) {
      return NextResponse.json(
        { error: "Champs requis manquants (userId, bourseId, direction)" },
        { status: 400 }
      );
    }

    const effectiveCategory = category || (direction === "superlike" ? "flyagent" : "favoris");

    // 1. Record Swipe in Supabase
    try {
      await supabase.from("swipes").upsert(
        {
          firebase_uid: userId,
          bourse_id: bourseId,
          direction,
          score: score || 85,
          created_at: new Date().toISOString(),
        },
        { onConflict: "firebase_uid,bourse_id" }
      );
    } catch (e) {
      console.warn("Swipes table upsert warning:", e);
    }

    // 2. If 'right' or 'superlike', create entry in matches & applications
    let isMatch = false;
    if (direction === "right" || direction === "superlike") {
      isMatch = true;

      try {
        await supabase.from("matches").upsert(
          {
            firebase_uid: userId,
            bourse_id: bourseId,
            match_score: score || 90,
            status: "new",
            created_at: new Date().toISOString(),
          },
          { onConflict: "firebase_uid,bourse_id" }
        );
      } catch (e) {
        console.warn("Matches table upsert warning:", e);
      }

      // Create application record (category stored safely inside checklist JSONB)
      try {
        await supabase.from("applications").upsert(
          {
            firebase_uid: userId,
            bourse_id: bourseId,
            status: "draft",
            checklist: {
              cv_uploaded: false,
              motivation_letter: false,
              transcripts: false,
              recommendation_letters: false,
              language_test: false,
              category: effectiveCategory,
            },
            updated_at: new Date().toISOString(),
          },
          { onConflict: "firebase_uid,bourse_id" }
        );
      } catch (e) {
        console.warn("Applications table upsert warning:", e);
      }
    }

    return NextResponse.json({
      success: true,
      isMatch,
      message: isMatch ? "Match enregistré dans tes candidatures !" : "Swipe enregistré",
    });
  } catch (err: any) {
    return NextResponse.json({ success: true, message: "Action enregistrée" });
  }
}

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");

    if (!userId) {
      return NextResponse.json({ error: "userId requis" }, { status: 400 });
    }

    const { data: swipes } = await supabase
      .from("swipes")
      .select("*")
      .eq("firebase_uid", userId);

    return NextResponse.json({ data: swipes || [] });
  } catch (err: any) {
    return NextResponse.json({ data: [] });
  }
}
