import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { calculateMatchScore } from "@/lib/matching";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const supabase = getSupabaseServerClient();

    const { data: bourse, error } = await supabase
      .from("bourses")
      .select("*")
      .eq("id", id)
      .single();

    if (error || !bourse) {
      return NextResponse.json({ error: "Bourss non trouvée" }, { status: 404 });
    }

    const defaultProfile = {
      degreeLevel: "master",
      fieldOfStudy: "Informatique",
      targetCountries: ["France", "Allemagne"],
      nationality: "International",
    };

    const matchBreakdown = calculateMatchScore(defaultProfile, bourse);

    return NextResponse.json({
      data: {
        ...bourse,
        matchScore: matchBreakdown.overallScore,
        matchBreakdown,
      },
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
