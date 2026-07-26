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
          targetDegreeLevel: null,
          fieldOfStudy: "Informatique",
          nationality: "Togo",
          university: "Université de Lomé",
          targetCountries: ["France", "Allemagne", "Canada", "Togo"],
          budgetMax: 15000,
          gpa: 3.5,
          languages: { english: "B2", french: "C1" },
          skills: [],
          photoUrl: "",
          cvUrl: "",
          onboardingCompleted: false,
          termsAccepted: false,
        },
      });
    }

    return NextResponse.json({
      data: {
        id: profile.firebase_uid,
        fullName: profile.full_name || "",
        email: profile.email || "",
        degreeLevel: profile.education_level || "master",
        targetDegreeLevel: profile.target_degree_level || null,
        fieldOfStudy: profile.field_of_study || "Informatique",
        nationality: profile.nationality || "Togo",
        university: profile.university || "Université de Lomé",
        targetCountries: profile.target_countries || ["France", "Allemagne", "Togo"],
        budgetMax: profile.budget_max || 15000,
        gpa: profile.gpa || 3.5,
        languages: profile.languages || { english: "B2", french: "C1" },
        skills: profile.skills || [],
        photoUrl: profile.photo_url || profile.avatar_url || "",
        cvUrl: profile.cv_url || "",
        onboardingCompleted: profile.onboarding_completed || false,
        termsAccepted: profile.terms_accepted || false,
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
      targetDegreeLevel,
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
      target_degree_level: targetDegreeLevel || null,
      field_of_study: fieldOfStudy || "Informatique",
      nationality: nationality || "Togo",
      university: university || "Université de Lomé",
      target_countries: targetCountries || ["France", "Allemagne", "Togo"],
      budget_max: budgetMax || 15000,
      gpa: gpa || 3.5,
      languages: languages || { english: "B2", french: "C1" },
      skills: skills || [],
      bio: bio || "",
      photo_url: photoUrl || avatarUrl || "",
      cv_url: cvUrl || "",
      onboarding_completed: onboardingCompleted || false,
      terms_accepted: termsAccepted || false,
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
        email: updated.email,
        degreeLevel: updated.education_level,
        targetDegreeLevel: updated.target_degree_level,
        fieldOfStudy: updated.field_of_study,
        nationality: updated.nationality,
        university: updated.university,
        targetCountries: updated.target_countries,
        budgetMax: updated.budget_max,
        gpa: updated.gpa,
        languages: updated.languages,
        skills: updated.skills,
        photoUrl: updated.photo_url,
        cvUrl: updated.cv_url,
        onboardingCompleted: updated.onboarding_completed,
        termsAccepted: updated.terms_accepted,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
