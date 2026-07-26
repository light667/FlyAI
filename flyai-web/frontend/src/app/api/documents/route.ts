import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

// Allowed document categories
const ALLOWED_CATEGORIES = [
  "CV",
  "Relevé de notes",
  "Diplôme",
  "Certificat de Langue",
  "Lettre de motivation",
  "Lettre de recommandation",
  "Passeport",
  "Photo d'identité",
  "Autre",
];

// Maximum file size: 10MB
const MAX_FILE_SIZE = 10 * 1024 * 1024;

// Allowed MIME types
const ALLOWED_MIME_TYPES = [
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
];

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const formData = await req.formData();

    const userId = formData.get("userId") as string;
    const category = formData.get("category") as string;
    const file = formData.get("file") as File | null;

    // Validation
    if (!userId) {
      return NextResponse.json(
        { error: "userId is required" },
        { status: 400 }
      );
    }

    if (!category || !ALLOWED_CATEGORIES.includes(category)) {
      return NextResponse.json(
        { error: "Invalid category" },
        { status: 400 }
      );
    }

    if (!file) {
      return NextResponse.json(
        { error: "No file uploaded" },
        { status: 400 }
      );
    }

    // Check file size
    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: `File size exceeds maximum limit of ${MAX_FILE_SIZE / 1024 / 1024}MB` },
        { status: 400 }
      );
    }

    // Check MIME type
    if (!ALLOWED_MIME_TYPES.includes(file.type)) {
      return NextResponse.json(
        { error: "File type not allowed. Allowed: PDF, JPEG, PNG, WebP, Word documents" },
        { status: 400 }
      );
    }

    // Generate unique filename
    const fileExt = file.name.split(".").pop()?.toLowerCase() || "file";
    const fileName = `${Date.now()}_${userId}_${category.replace(/\s+/g, "_")}.${fileExt}`;

    // Use existing 'documents' bucket with cvs/ and photos/ folders
    const bucketName = "documents";
    
    // Determine folder based on category
    const folder = category === "Photo d'identité" ? "photos" : "cvs";
    const storagePath = `${folder}/${userId}/${fileName}`;

    // Upload file to the appropriate folder
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from(bucketName)
      .upload(storagePath, file, {
        contentType: file.type,
        upsert: false,
      });

    if (uploadError) {
      console.error("Error uploading file:", uploadError);
      return NextResponse.json(
        { error: "Failed to upload file", details: uploadError.message },
        { status: 500 }
      );
    }

    // Get public URL (with signed URL for private bucket)
    const { data: urlData, error: urlError } = await supabase.storage
      .from(bucketName)
      .createSignedUrl(storagePath, 3600 * 24 * 365); // 1 year expiry

    if (urlError) {
      console.error("Error creating signed URL:", urlError);
    }

    // If this is a profile photo, update the user's avatar_url in profiles table
    if (category === "Photo d'identité" && urlData?.signedUrl) {
      const { error: updateAvatarError } = await supabase
        .from("profiles")
        .update({ avatar_url: urlData.signedUrl })
        .eq("firebase_uid", userId);

      if (updateAvatarError) {
        console.error("Error updating avatar_url:", updateAvatarError);
      }
    }

    // Save document metadata to database
    const documentData = {
      id: uploadData.path,
      firebase_uid: userId,
      file_name: file.name,
      stored_name: fileName,
      category: category,
      file_size: file.size,
      mime_type: file.type,
      file_extension: fileExt,
      storage_path: storagePath,
      bucket: bucketName,
      folder: folder,
      download_url: urlData?.signedUrl || "",
      uploaded_at: new Date().toISOString(),
      status: "uploaded",
    };

    // Save to application_documents table (or create a new documents table)
    // For now, we'll save to a documents table
    const { data: docRecord, error: docError } = await supabase
      .from("application_documents")
      .insert(documentData)
      .select()
      .single();

    if (docError) {
      console.error("Error saving document metadata:", docError);
      // Even if DB save fails, return upload success with URL
      return NextResponse.json({
        success: true,
        message: "File uploaded successfully",
        url: urlData?.signedUrl,
        path: uploadData.path,
        fileName: file.name,
        category,
      });
    }

    return NextResponse.json({
      success: true,
      message: "Document uploaded successfully",
      data: {
        id: docRecord.id,
        fileName: docRecord.file_name,
        category: docRecord.category,
        size: docRecord.file_size,
        url: docRecord.download_url,
        storagePath: docRecord.storage_path,
        uploadedAt: docRecord.uploaded_at,
      },
    });
  } catch (err: any) {
    console.error("Document upload error:", err);
    return NextResponse.json(
      { error: err.message || "Internal server error" },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");

    if (!userId) {
      return NextResponse.json(
        { error: "userId is required" },
        { status: 400 }
      );
    }

    // Fetch documents from database
    const { data: documents, error } = await supabase
      .from("application_documents")
      .select("*")
      .eq("firebase_uid", userId)
      .order("uploaded_at", { ascending: false });

    if (error) {
      console.error("Error fetching documents:", error);
      return NextResponse.json(
        { error: error.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      data: documents || [],
    });
  } catch (err: any) {
    console.error("Fetch documents error:", err);
    return NextResponse.json(
      { error: err.message || "Internal server error" },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get("userId");
    const documentId = searchParams.get("documentId");

    if (!userId || !documentId) {
      return NextResponse.json(
        { error: "userId and documentId are required" },
        { status: 400 }
      );
    }

    // First, get the document to find the storage path
    const { data: document, error: fetchError } = await supabase
      .from("application_documents")
      .select("*")
      .eq("id", documentId)
      .eq("firebase_uid", userId)
      .maybeSingle();

    if (fetchError || !document) {
      return NextResponse.json(
        { error: "Document not found" },
        { status: 404 }
      );
    }

    // If this is a profile photo, also reset the avatar_url in profiles table
    if (document.category === "Photo d'identité") {
      const { error: resetAvatarError } = await supabase
        .from("profiles")
        .update({ avatar_url: "" })
        .eq("firebase_uid", userId);

      if (resetAvatarError) {
        console.error("Error resetting avatar_url:", resetAvatarError);
      }
    }

    // Delete from storage
    const { error: deleteStorageError } = await supabase.storage
      .from(document.bucket)
      .remove([document.storage_path]);

    if (deleteStorageError) {
      console.error("Error deleting from storage:", deleteStorageError);
    }

    // Delete from database
    const { error: deleteDbError } = await supabase
      .from("application_documents")
      .delete()
      .eq("id", documentId)
      .eq("firebase_uid", userId);

    if (deleteDbError) {
      console.error("Error deleting from database:", deleteDbError);
      return NextResponse.json(
        { error: "Failed to delete document from database" },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      message: "Document deleted successfully",
    });
  } catch (err: any) {
    console.error("Delete document error:", err);
    return NextResponse.json(
      { error: err.message || "Internal server error" },
      { status: 500 }
    );
  }
}
