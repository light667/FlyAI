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

    const { data: profile, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("firebase_uid", userId)
      .maybeSingle();

    if (error || !profile) {
      // Default fallback profile if record not found or table initializing
      return NextResponse.json({
        data: {
          id: userId,
          fullName: "",
          email: "",
          degreeLevel: "master",
          fieldOfStudy: "Informatique",
          nationality: "International",
          targetCountries: ["France", "Allemagne", "Canada"],
          budgetMax: 15000,
          gpa: 3.5,
          languages: { english: "B2", french: "C1" },
          skills: [],
        },
      });
    }

    return NextResponse.json({
      data: {
        id: profile.firebase_uid,
        fullName: profile.full_name || "",
        email: profile.email || "",
        degreeLevel: profile.education_level || "master",
        fieldOfStudy: profile.field_of_study || "Informatique",
        nationality: profile.nationality || "International",
        targetCountries: profile.target_countries || ["France", "Allemagne"],
        budgetMax: 15000,
        gpa: profile.gpa || 3.5,
        languages: profile.languages || { english: "B2", french: "C1" },
        skills: profile.skills || [],
        cvUrl: profile.cv_url || "",
        avatarUrl: profile.avatar_url || "",
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const {
      userId,
      fullName,
      email,
      degreeLevel,
      fieldOfStudy,
      nationality,
      targetCountries,
      gpa,
      languages,
      skills,
      bio,
      cvUrl,
      avatarUrl,
    } = body;

    if (!userId) {
      return NextResponse.json({ error: "userId requis" }, { status: 400 });
    }

    const profileData = {
      firebase_uid: userId,
      full_name: fullName || "Étudiant FlyAI",
      email: email || "",
      education_level: degreeLevel || "master",
      field_of_study: fieldOfStudy || "Informatique",
      nationality: nationality || "International",
      target_countries: targetCountries || ["France", "Allemagne"],
      gpa: gpa || 3.5,
      languages: languages || { english: "B2", french: "C1" },
      skills: skills || [],
      bio: bio || "",
      cv_url: cvUrl || "",
      avatar_url: avatarUrl || "",
      updated_at: new Date().toISOString(),
    };

    const { data: updated, error } = await supabase
      .from("profiles")
      .upsert(profileData, { onConflict: "firebase_uid" })
      .select()
      .single();

    if (error) {
      console.error("Error upserting profile:", error);
      return NextResponse.json({
        success: false,
        error: error.message,
      }, { status: 500 });
    }

    return NextResponse.json({
      success: true,
      data: {
        id: updated.firebase_uid,
        fullName: updated.full_name,
        degreeLevel: updated.education_level,
        fieldOfStudy: updated.field_of_study,
        nationality: updated.nationality,
        targetCountries: updated.target_countries,
        gpa: updated.gpa,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
