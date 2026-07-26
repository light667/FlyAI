import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

/**
 * Generate application checklist based on scholarship requirements and user profile
 * This creates a personalized checklist for a specific scholarship application
 */
function generateChecklist(scholarship: any, userProfile: any): { items: any[], completion: number } {
  const checklistItems: any[] = [];
  
  // Standard required documents for most scholarships
  const standardDocuments = [
    {
      key: "application_form",
      label: "Formulaire officiel de candidature",
      description: "Formulaire rempli et signé",
      required: true,
      category: "Formulaire",
      estimatedTime: "30 min",
    },
    {
      key: "transcripts",
      label: "Relevés de notes certifiés",
      description: "Relevés officiels avec traduction assermentée si nécessaire",
      required: true,
      category: "Académique",
      estimatedTime: "1-2 semaines (traduction)",
    },
    {
      key: "motivation_letter",
      label: "Lettre de motivation",
      description: "Lettre personnalisée pour cette bourse",
      required: true,
      category: "Document personnel",
      estimatedTime: "2-3 heures",
    },
    {
      key: "cv",
      label: "CV académique",
      description: "CV format international (Europass ou équivalent)",
      required: true,
      category: "Document personnel",
      estimatedTime: "1-2 heures",
    },
  ];

  // Language proficiency documents based on scholarship requirements
  const languageDocs = [
    {
      key: "language_certificate",
      label: "Certificat de langue",
      description: `Certificat ${scholarship.langues_requises?.join(" ou ") || "TOEFL/IELTS/DELF"} valide`,
      required: scholarship.langues_requises && scholarship.langues_requises.length > 0,
      category: "Langue",
      estimatedTime: "1-4 semaines (préparation + test)",
    },
  ];

  // Recommendation letters
  const recommendationLetters = [
    {
      key: "recommendation_1",
      label: "Lettre de recommandation #1",
      description: "Lettre d'un professeur ou employeur",
      required: true,
      category: "Recommandation",
      estimatedTime: "1-2 semaines (délai professeur)",
    },
    {
      key: "recommendation_2",
      label: "Lettre de recommandation #2",
      description: "Lettre d'un second professeur ou employeur",
      required: true,
      category: "Recommandation",
      estimatedTime: "1-2 semaines (délai professeur)",
    },
  ];

  // Scholarship-specific documents based on criteria
  const scholarshipSpecific: any[] = [];
  
  if (scholarship.criteres && scholarship.criteres.length > 0) {
    scholarship.criteres.forEach((criterion: string, index: number) => {
      if (criterion.toLowerCase().includes("essai") || criterion.toLowerCase().includes("essay")) {
        scholarshipSpecific.push({
          key: `essay_${index}`,
          label: "Essai / Dissertation",
          description: criterion,
          required: true,
          category: "Essai",
          estimatedTime: "4-8 heures",
        });
      }
      if (criterion.toLowerCase().includes("projet") || criterion.toLowerCase().includes("project")) {
        scholarshipSpecific.push({
          key: `project_proposal_${index}`,
          label: "Proposition de projet de recherche",
          description: criterion,
          required: true,
          category: "Projet",
          estimatedTime: "1-2 semaines",
        });
      }
      if (criterion.toLowerCase().includes("portfolio")) {
        scholarshipSpecific.push({
          key: `portfolio_${index}`,
          label: "Portfolio",
          description: criterion,
          required: true,
          category: "Portfolio",
          estimatedTime: "2-4 heures",
        });
      }
      if (criterion.toLowerCase().includes("video") || criterion.toLowerCase().includes("vidéo")) {
        scholarshipSpecific.push({
          key: `video_${index}`,
          label: "Vidéo de présentation",
          description: criterion,
          required: true,
          category: "Multimédia",
          estimatedTime: "1-2 jours",
        });
      }
    });
  }

  // Add all items to checklist
  checklistItems.push(...standardDocuments, ...languageDocs, ...recommendationLetters, ...scholarshipSpecific);

  // Calculate completion based on user profile
  let completedCount = 0;
  checklistItems.forEach((item) => {
    // Check if user has this document based on profile
    const userDocs = userProfile?.documents || [];
    if (userDocs.some((doc: any) => doc.category === item.category)) {
      completedCount++;
      item.completed = true;
    } else {
      item.completed = false;
    }
  });

  const completion = Math.round((completedCount / checklistItems.length) * 100);

  return { items: checklistItems, completion };
}

/**
 * Generate motivation letter draft based on scholarship and user profile
 * This creates a personalized motivation letter that can be refined
 */
function generateMotivationLetter(scholarship: any, userProfile: any): { draft: string, suggestions: string[] } {
  const suggestions: string[] = [];
  
  // Extract relevant information
  const userDegree = userProfile?.degreeLevel || "Master";
  const userField = userProfile?.fieldOfStudy || "Informatique";
  const userNationality = userProfile?.nationality || "International";
  const userGPA = userProfile?.gpa || 3.5;
  const userLanguages = userProfile?.languages || {};
  const userSkills = userProfile?.skills || [];
  const userGoals = userProfile?.academicGoals || "poursuivre mes études dans un environnement académique d'excellence";

  const scholarshipTitle = scholarship.titre || "cette bourse";
  const scholarshipCountry = scholarship.pays_destination?.join(", ") || "le pays de destination";
  const scholarshipLevel = scholarship.niveau_etude?.join(", ") || "Master";
  const scholarshipFinancing = scholarship.financement || "partiel";
  const scholarshipDescription = scholarship.description || "";

  // Build letter
  let draft = `Madame, Monsieur les membres du jury,\n\n`;
  
  // Introduction
  draft += `Actuellement étudiant(e) en ${userDegree} spécialité ${userField} à l'${userProfile?.university || "université"}, `;
  draft += `c'est avec un grand intérêt que je vous adresse ma candidature pour la bourse ${scholarshipTitle}.\n\n`;

  // Academic background
  draft += `Mon parcours académique, marqué par ${userSkills.length > 0 ? "des compétences en " + userSkills.join(", ") + ", " : ""}`;
  draft += `un niveau moyen de ${userGPA}/4, et une spécialisation en ${userField}, `;
  draft += `m'a préparé à relever les défis de ce programme exigeant.\n\n`;

  // Connection to scholarship
  draft += `La bourse ${scholarshipTitle} représente pour moi une opportunité unique de ${userGoals.toLowerCase()}. `;
  draft += `Le programme proposé, avec son focus sur ${scholarship.domaines?.join(", ") || "des domaines d'excellence"}, `;
  draft += `correspond parfaitement à mon projet académique et professionnel.\n\n`;

  // Why this scholarship
  draft += `Je suis particulièrement attiré(e) par cette opportunité car elle offre :\n`;
  if (scholarship.avantages && scholarship.avantages.length > 0) {
    scholarship.avantages.forEach((advantage: string, index: number) => {
      draft += `  - ${advantage}\n`;
    });
  } else {
    draft += `  - Un financement ${scholarshipFinancing} qui me permettrait de me concentrer pleinement sur mes études\n`;
    draft += `  - L'accès à un environnement académique de haut niveau\n`;
    draft += `  - La possibilité de contribuer au développement de mon domaine\n`;
  }
  draft += `\n`;

  // Language proficiency
  if (scholarship.langues_requises && scholarship.langues_requises.length > 0) {
    draft += `Par ailleurs, je possède les compétences linguistiques requises, avec `;
    const languageTexts = [];
    if (userLanguages.english) languageTexts.push(`un niveau d'anglais ${userLanguages.english}`);
    if (userLanguages.french) languageTexts.push(`un niveau de français ${userLanguages.french}`);
    draft += languageTexts.join(" et ") + ".\n\n";
  }

  // Conclusion
  draft += `En conclusion, je suis convaincu(e) que mon profil correspond aux exigences de cette bourse prestigieuse. `;
  draft += `Je me tiens à votre disposition pour toute information complémentaire et vous remercie de l'attention portée à ma candidature.\n\n`;
  draft += `Veuillez agréer, Madame, Monsieur, l'expression de mes salutations distinguées.\n\n`;
  draft += `${userProfile?.fullName || "Le candidat"}\n`;

  // Add suggestions for improvement
  if (!userProfile?.cv_url) {
    suggestions.push("Ajoutez votre CV pour compléter votre dossier");
  }
  if (!userProfile?.academicGoals || userProfile.academicGoals.length < 50) {
    suggestions.push("Développez vos objectifs académiques pour personnaliser davantage la lettre");
  }
  if (!userProfile?.bio || userProfile.bio.length < 100) {
    suggestions.push("Ajoutez une biographie détaillée pour enrichir votre profil");
  }

  return { draft, suggestions };
}

/**
 * Generate project/proposal if required by scholarship
 */
function generateProjectProposal(scholarship: any, userProfile: any): string | null {
  const hasProjectRequirement = scholarship.criteres?.some((c: string) => 
    c.toLowerCase().includes("projet") || c.toLowerCase().includes("project")
  );
  
  if (!hasProjectRequirement) return null;

  const userField = userProfile?.fieldOfStudy || "Informatique";
  const userGoals = userProfile?.academicGoals || "contribuer au développement des technologies de pointe";

  return `Titre du projet : Étude et développement de solutions innovantes en ${userField}\n\n` +
    `Contexte :\n` +
    `Ce projet s'inscrit dans le cadre de ma volonté de ${userGoals}. ` +
    `Il vise à explorer les applications pratiques de ${userField} pour répondre à des défis actuels.\n\n` +
    `Objectifs :\n` +
    `- Analyser les besoins spécifiques dans le domaine de ${userField}\n` +
    `- Développer des solutions innovantes et durables\n` +
    `- Valider les résultats par des tests rigoureux\n\n` +
    `Méthodologie :\n` +
    `Cette étude utilisera des méthodes de recherche qualitatives et quantitatives, ` +
    `incluant des entretiens avec des experts, des analyses de données, et des expérimentations pratiques.\n\n` +
    `Résultats attendus :\n` +
    `Les résultats de ce projet contribueront à l'avancement des connaissances en ${userField} ` +
    `et pourront être publiés dans des revues scientifiques ou présentés lors de conférences internationales.\n`;
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const { userId, scholarshipId, userProfile } = body;

    if (!userId || !scholarshipId) {
      return NextResponse.json(
        { error: "userId and scholarshipId are required" },
        { status: 400 }
      );
    }

    // Fetch scholarship details
    const { data: scholarship, error: scholarshipError } = await supabase
      .from("bourses")
      .select("*")
      .eq("id", scholarshipId)
      .maybeSingle();

    if (scholarshipError || !scholarship) {
      return NextResponse.json(
        { error: "Scholarship not found" },
        { status: 404 }
      );
    }

    // Generate checklist
    const checklist = generateChecklist(scholarship, userProfile);

    // Generate motivation letter
    const letter = generateMotivationLetter(scholarship, userProfile);

    // Generate project proposal if needed
    const projectProposal = generateProjectProposal(scholarship, userProfile);

    // Save to applications table
    const applicationData = {
      firebase_uid: userId,
      bourse_id: scholarshipId,
      status: "draft",
      checklist: checklist.items,
      notes: letter.suggestions.join("\n"),
      deadline: scholarship.deadline,
      application_url: scholarship.lien_candidature,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: application, error: appError } = await supabase
      .from("applications")
      .upsert(applicationData, { onConflict: "firebase_uid, bourse_id" })
      .select()
      .single();

    if (appError) {
      console.error("Error saving application:", appError);
    }

    // Save motivation letter to documents
    if (letter.draft && userId) {
      const letterDoc = {
        firebase_uid: userId,
        file_name: `Lettre_Motivation_${scholarshipId}.txt`,
        category: "Lettre de motivation",
        file_size: letter.draft.length,
        mime_type: "text/plain",
        file_extension: "txt",
        storage_path: `auto-generated/letters/${userId}/${scholarshipId}`,
        bucket: "user-documents",
        download_url: "",
        uploaded_at: new Date().toISOString(),
        status: "generated",
        content: letter.draft,
        scholarship_id: scholarshipId,
      };

      await supabase.from("application_documents").insert(letterDoc);
    }

    return NextResponse.json({
      success: true,
      applicationId: application?.id,
      scholarship,
      checklist: checklist.items,
      completion: checklist.completion,
      motivationLetter: letter.draft,
      letterSuggestions: letter.suggestions,
      projectProposal,
      message: "Application started successfully with FlyAgent",
    });
  } catch (err: any) {
    console.error("Apply with FlyAgent error:", err);
    return NextResponse.json(
      { error: err.message || "Failed to start application with FlyAgent" },
      { status: 500 }
    );
  }
}

/**
 * Get existing application for a user and scholarship
 */
export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");
    const scholarshipId = searchParams.get("scholarshipId");

    if (!userId || !scholarshipId) {
      return NextResponse.json(
        { error: "userId and scholarshipId are required" },
        { status: 400 }
      );
    }

    // Fetch application
    const { data: application, error: appError } = await supabase
      .from("applications")
      .select("*")
      .eq("firebase_uid", userId)
      .eq("bourse_id", scholarshipId)
      .maybeSingle();

    if (appError && !application) {
      return NextResponse.json(
        { error: appError?.message || "Application not found" },
        { status: 404 }
      );
    }

    // Fetch scholarship
    const { data: scholarship, error: schError } = await supabase
      .from("bourses")
      .select("*")
      .eq("id", scholarshipId)
      .maybeSingle();

    // Fetch user profile
    const { data: profile, error: profError } = await supabase
      .from("profiles")
      .select("*")
      .eq("firebase_uid", userId)
      .maybeSingle();

    // Generate fresh checklist and letter based on current data
    const checklist = generateChecklist(scholarship || {}, profile || {});
    const letter = generateMotivationLetter(scholarship || {}, profile || {});

    return NextResponse.json({
      success: true,
      application,
      scholarship,
      userProfile: profile,
      checklist: checklist.items,
      completion: checklist.completion,
      motivationLetter: letter.draft,
      letterSuggestions: letter.suggestions,
    });
  } catch (err: any) {
    console.error("Get application error:", err);
    return NextResponse.json(
      { error: err.message || "Failed to fetch application" },
      { status: 500 }
    );
  }
}
