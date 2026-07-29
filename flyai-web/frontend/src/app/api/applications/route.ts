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

    // 1. Fetch applications without SQL joins (prevents PGRST200 foreign key relationship errors)
    const { data: applications, error: appError } = await supabase
      .from("applications")
      .select("*")
      .eq("firebase_uid", userId)
      .order("updated_at", { ascending: false });

    if (appError) {
      console.warn("Applications fetch warning:", appError.message);
    }

    // 2. Fetch liked/superliked swipes to ensure ALL liked bourses are retrieved
    const { data: swipes, error: swipeError } = await supabase
      .from("swipes")
      .select("*")
      .eq("firebase_uid", userId)
      .in("direction", ["right", "superlike"]);

    if (swipeError) {
      console.warn("Swipes fetch warning:", swipeError.message);
    }

    // 3. Gather all unique bourse_ids from applications & swipes
    const allBourseIds = new Set<string>();
    (applications || []).forEach((a) => { if (a.bourse_id) allBourseIds.add(a.bourse_id); });
    (swipes || []).forEach((s) => { if (s.bourse_id) allBourseIds.add(s.bourse_id); });

    // 4. Fetch bourses details manually
    let boursesMap: Record<string, any> = {};
    if (allBourseIds.size > 0) {
      const { data: boursesData } = await supabase
        .from("bourses")
        .select("*")
        .in("id", Array.from(allBourseIds));

      if (boursesData) {
        boursesData.forEach((b) => {
          boursesMap[b.id] = b;
        });
      }
    }

    // 5. Build merged applications list
    const appBourseIds = new Set((applications || []).map((a) => a.bourse_id));
    const mergedList: any[] = [...(applications || [])];

    if (swipes && swipes.length > 0) {
      for (const sw of swipes) {
        if (!appBourseIds.has(sw.bourse_id)) {
          mergedList.push({
            id: `sw_${sw.id}`,
            firebase_uid: userId,
            bourse_id: sw.bourse_id,
            status: "draft",
            checklist: {
              cv_uploaded: false,
              motivation_letter: false,
              transcripts: false,
              recommendation_letters: false,
              category: sw.direction === "superlike" ? "flyagent" : "favoris",
            },
            created_at: sw.created_at,
            updated_at: sw.created_at,
          });
        }
      }
    }

    // 6. Normalize records to Application type with mapped bourse details
    const normalized = mergedList.map((app) => {
      const cl = app.checklist || {};
      const cat = cl.category || app.category || "favoris";
      const bourseObj = boursesMap[app.bourse_id] || null;

      return {
        id: app.id,
        userId: app.firebase_uid,
        bourseId: app.bourse_id,
        bourse: bourseObj,
        status: app.status || "draft",
        category: cat,
        checklist: cl,
        notes: app.notes || "",
        deadline: app.deadline || bourseObj?.deadline || null,
        applicationUrl: app.application_url || bourseObj?.lien_candidature || "",
        createdAt: app.created_at || new Date().toISOString(),
        updatedAt: app.updated_at || new Date().toISOString(),
      };
    });

    return NextResponse.json({ data: normalized });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const { userId, bourseId, status, checklist, notes, deadline, applicationUrl, category } = body;

    if (!userId || !bourseId) {
      return NextResponse.json({ error: "userId et bourseId requis" }, { status: 400 });
    }

    const effectiveChecklist = {
      cv_uploaded: false,
      motivation_letter: false,
      transcripts: false,
      recommendation_letters: false,
      language_test: false,
      ...(checklist || {}),
    };
    if (category) {
      effectiveChecklist.category = category;
    }

    const appData: Record<string, any> = {
      firebase_uid: userId,
      bourse_id: bourseId,
      status: status || "draft",
      checklist: effectiveChecklist,
      notes: notes || "",
      deadline: deadline || null,
      application_url: applicationUrl || "",
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from("applications")
      .upsert(appData, { onConflict: "firebase_uid,bourse_id" })
      .select()
      .maybeSingle();

    if (error) {
      console.error("Error upserting application:", error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Fetch bourse manually
    const { data: bourseObj } = await supabase
      .from("bourses")
      .select("*")
      .eq("id", bourseId)
      .maybeSingle();

    return NextResponse.json({
      success: true,
      data: {
        ...data,
        bourse: bourseObj || null,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
