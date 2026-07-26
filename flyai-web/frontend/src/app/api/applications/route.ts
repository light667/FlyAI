import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");

    if (!userId) {
      return NextResponse.json({ error: "userId requis" }, { status: 400 });
    }

    const { data: applications, error } = await supabase
      .from("applications")
      .select("*, bourses(*)")
      .eq("firebase_uid", userId)
      .order("updated_at", { ascending: false });

    if (error) {
      console.error("Error fetching applications:", error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ data: applications || [] });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const { userId, bourseId, status, checklist, notes, deadline, applicationUrl } = body;

    if (!userId || !bourseId) {
      return NextResponse.json({ error: "userId et bourseId requis" }, { status: 400 });
    }

    const defaultChecklist = {
      cv_uploaded: false,
      motivation_letter: false,
      transcripts: false,
      recommendation_letters: false,
      language_test: false,
    };

    const { data, error } = await supabase.from("applications").upsert(
      {
        firebase_uid: userId,
        bourse_id: bourseId,
        status: status || "draft",
        checklist: checklist || defaultChecklist,
        notes: notes || "",
        deadline: deadline || null,
        application_url: applicationUrl || "",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "firebase_uid,bourse_id" }
    ).select("*, bourses(*)").single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
