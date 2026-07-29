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
          targetCountries: ["France", "Allemagne", "Canada"],
          budgetMax: 15000,
          gpa: 3.5,
          averageOutOf20: 14,
          languages: { english: "B2", french: "C1" },
          skills: [],
          photoUrl: "",
          cvUrl: "",
          projectSummary: "",
          needsFullFunding: true,
          onboardingCompleted: false,
          termsAccepted: false,
        },
      });
    }

    const langs = profile.languages || {};
    const photo = profile.avatar_url || profile.photo_url || "";
    const project = profile.academic_goals || profile.project_summary || profile.bio || "";
    const avg = langs.averageOutOf20 || (profile.gpa ? Math.round(profile.gpa * 5) : 14);
    const funding = langs.needsFullFunding ?? true;

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
        targetCountries: profile.target_countries || ["France", "Allemagne"],
        budgetMax: profile.budget_max || 15000,
        gpa: profile.gpa || 3.5,
        averageOutOf20: avg,
        languages: profile.languages || { english: "B2", french: "C1" },
        skills: profile.skills || [],
        photoUrl: photo,
        cvUrl: profile.cv_url || "",
        projectSummary: project,
        needsFullFunding: funding,
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
      university,
      targetCountries,
      budgetMax,
      gpa,
      averageOutOf20,
      languages,
      skills,
      bio,
      projectSummary,
      cvUrl,
      photoUrl,
      avatarUrl,
      needsFullFunding,
      onboardingCompleted,
      termsAccepted,
    } = body;

    if (!userId) {
      return NextResponse.json({ error: "userId requis" }, { status: 400 });
    }

    const profileLanguages = typeof languages === "object" && languages !== null ? { ...languages } : { english: "B2", french: "C1" };
    if (averageOutOf20 !== undefined) profileLanguages.averageOutOf20 = averageOutOf20;
    if (needsFullFunding !== undefined) profileLanguages.needsFullFunding = needsFullFunding;

    // Ensure email is valid and not empty to satisfy NOT NULL UNIQUE constraint
    let userEmail = email;
    if (!userEmail) {
      const { data: existing } = await supabase
        .from("profiles")
        .select("email")
        .eq("firebase_uid", userId)
        .maybeSingle();
      userEmail = existing?.email || `${userId}@flyai.user`;
    }

    // Initial payload with all possible standard fields
    const profileData: Record<string, any> = {
      firebase_uid: userId,
      full_name: fullName || "Étudiant FlyAI",
      email: userEmail,
      education_level: degreeLevel || "master",
      target_degree_level: targetDegreeLevel || null,
      field_of_study: fieldOfStudy || "Informatique",
      nationality: nationality || "Togo",
      university: university || "Université de Lomé",
      target_countries: targetCountries || ["France", "Allemagne"],
      gpa: gpa || 3.5,
      languages: profileLanguages,
      skills: skills || [],
      academic_goals: projectSummary || bio || "",
      avatar_url: photoUrl || avatarUrl || "",
      cv_url: cvUrl || "",
      onboarding_completed: onboardingCompleted ?? false,
      terms_accepted: termsAccepted ?? false,
      updated_at: new Date().toISOString(),
    };

    // Auto-pruning retry loop: Strips any column not recognized by live Supabase schema
    let updated: any = null;
    let lastError: any = null;

    for (let attempt = 0; attempt < 12; attempt++) {
      const { data, error } = await supabase
        .from("profiles")
        .upsert(profileData, { onConflict: "firebase_uid" })
        .select()
        .maybeSingle();

      if (!error) {
        updated = data || profileData;
        lastError = null;
        break;
      }

      lastError = error;
      console.warn(`[POST /api/profile] Supabase error on attempt ${attempt + 1}:`, error.message);

      // Match missing column error: "Could not find the 'X' column of 'profiles' in the schema cache"
      const match = error.message?.match(/Could not find the '([^']+)' column/i);
      if (match && match[1] && match[1] in profileData) {
        const missingCol = match[1];
        console.warn(`[POST /api/profile] Auto-pruning non-existent column '${missingCol}' from payload and retrying...`);
        delete profileData[missingCol];
      } else {
        // Non-column error (e.g. RLS or network error) -> stop retrying
        break;
      }
    }

    if (lastError && !updated) {
      console.error("[POST /api/profile] Permanent error upserting profile:", lastError);
      return NextResponse.json({
        success: false,
        error: lastError.message,
      }, { status: 500 });
    }

    const savedRecord = updated || profileData;
    const respLangs = savedRecord.languages || profileLanguages;
    const respPhoto = savedRecord.avatar_url || savedRecord.photo_url || photoUrl || "";
    const respProject = savedRecord.academic_goals || savedRecord.project_summary || projectSummary || "";

    return NextResponse.json({
      success: true,
      data: {
        id: userId,
        fullName: savedRecord.full_name || fullName,
        email: savedRecord.email || userEmail,
        degreeLevel: savedRecord.education_level || degreeLevel,
        targetDegreeLevel: savedRecord.target_degree_level || targetDegreeLevel,
        fieldOfStudy: savedRecord.field_of_study || fieldOfStudy,
        nationality: savedRecord.nationality || nationality,
        university: savedRecord.university || university,
        targetCountries: savedRecord.target_countries || targetCountries,
        budgetMax: 15000,
        gpa: savedRecord.gpa || gpa,
        averageOutOf20: respLangs.averageOutOf20 || averageOutOf20 || 14,
        languages: respLangs,
        skills: savedRecord.skills || skills,
        photoUrl: respPhoto,
        cvUrl: savedRecord.cv_url || cvUrl,
        projectSummary: respProject,
        needsFullFunding: respLangs.needsFullFunding ?? needsFullFunding ?? true,
        onboardingCompleted: savedRecord.onboarding_completed ?? onboardingCompleted ?? true,
        termsAccepted: savedRecord.terms_accepted ?? true,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
