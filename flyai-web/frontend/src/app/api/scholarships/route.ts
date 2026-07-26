import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { rankScholarshipsForProfile } from "@/lib/matching";

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);

    const search = searchParams.get("search") || "";
    const country = searchParams.get("country") || "";
    const degree = searchParams.get("degree") || "";
    const funding = searchParams.get("funding") || "";
    const userId = searchParams.get("userId") || "";
    const page = parseInt(searchParams.get("page") || "1");
    const limit = parseInt(searchParams.get("limit") || "40");
    const offset = (page - 1) * limit;

    let query = supabase
      .from("bourses")
      .select("*", { count: "exact" })
      .eq("active", true);

    if (search) {
      query = query.or(`titre.ilike.%${search}%,description.ilike.%${search}%`);
    }

    if (country) {
      query = query.contains("pays_destination", [country]);
    }

    if (funding && funding !== "ALL") {
      query = query.eq("financement", funding);
    }

    const { data: bourses, count, error } = await query
      .order("deadline", { ascending: true, nullsFirst: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error("Error fetching bourses:", error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Fetch user profile if userId provided
    let userProfile = null;
    if (userId) {
      const { data: prof } = await supabase
        .from("profiles")
        .select("*")
        .eq("firebase_uid", userId)
        .maybeSingle();

      if (prof) {
        userProfile = {
          degreeLevel: prof.education_level || "master",
          fieldOfStudy: prof.field_of_study || "Informatique",
          targetCountries: prof.target_countries || ["France", "Allemagne"],
          nationality: prof.nationality || "International",
          budgetMax: 15000,
        };
      }
    }

    const defaultProfile = userProfile || {
      degreeLevel: degree || "master",
      fieldOfStudy: "Informatique",
      targetCountries: country ? [country] : ["France", "Allemagne", "Canada"],
      nationality: "International",
      budgetMax: 15000,
    };

    const rankedBourses = rankScholarshipsForProfile(defaultProfile, bourses || [], degree || undefined);

    return NextResponse.json({
      data: rankedBourses,
      total: count || 0,
      page,
      limit,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
