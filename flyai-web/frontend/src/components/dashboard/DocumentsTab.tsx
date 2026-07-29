"use client";

import { useState, useEffect, useRef } from "react";
import { UserProfile } from "@/types";
import { FileText, UploadCloud, Trash2, CheckCircle2, Download, AlertCircle, Loader2 } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

const DOCUMENT_CATEGORIES = [
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

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const ALLOWED_EXTENSIONS = [".pdf", ".jpg", ".jpeg", ".png", ".webp", ".doc", ".docx"];

interface DocumentItem {
  id: string;
  file_name: string;
  category: string;
  file_size: number;
  mime_type: string;
  file_extension: string;
  storage_path: string;
  bucket: string;
  folder?: string;
  download_url: string;
  uploaded_at: string;
  status: string;
}

function formatFileSize(bytes: number): string {
  if (bytes === 0) return "0 Bytes";
  const k = 1024;
  const sizes = ["Bytes", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString("fr-FR", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function getCategoryIcon(category: string): string {
  const icons: Record<string, string> = {
    CV: "📄",
    "Relevé de notes": "📊",
    Diplôme: "🎓",
    "Certificat de Langue": "🌍",
    "Lettre de motivation": "✉️",
    "Lettre de recommandation": "💼",
    Passeport: "🛂",
    "Photo d'identité": "👤",
    Autre: "📁",
  };
  return icons[category] || "📄";
}

function getCategoryColor(category: string): { background: string; color: string } {
  const colors: Record<string, { background: string; color: string }> = {
    CV: { background: "var(--accent-50)", color: "var(--accent)" },
    "Relevé de notes": { background: "var(--success-light)", color: "var(--success)" },
    Diplôme: { background: "var(--warning-light)", color: "var(--warning)" },
    "Certificat de Langue": { background: "var(--alert-light)", color: "var(--alert)" },
    "Lettre de motivation": { background: "var(--info-light)", color: "var(--info)" },
    "Lettre de recommandation": { background: "var(--accent-100)", color: "var(--accent)" },
    Passeport: { background: "var(--info-light)", color: "var(--info)" },
    "Photo d'identité": { background: "var(--alert-light)", color: "var(--alert)" },
    Autre: { background: "var(--warm-200)", color: "var(--ink-subtle)" },
  };
  return colors[category] || { background: "var(--warm-200)", color: "var(--ink-subtle)" };
}

function isProfilePhoto(category: string): boolean {
  return category === "Photo d'identité";
}

export default function DocumentsTab({ userId, userProfile }: Props) {
  const [documents, setDocuments] = useState<DocumentItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  
  const [selectedCategory, setSelectedCategory] = useState<string>(DOCUMENT_CATEGORIES[0]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (userId) {
      fetchDocuments();
    }
  }, [userId]);

  const fetchDocuments = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/documents?userId=${userId}`);
      const json = await res.json();
      if (json.success && json.data) {
        setDocuments(json.data);
      }
    } catch (e) {
      console.error("Error fetching documents:", e);
    } finally {
      setLoading(false);
    }
  };

  // Combine uploaded documents with CV & Photo from userProfile
  const allDocuments = [...documents];
  if (userProfile?.cvUrl && !allDocuments.some((d) => d.category === "CV" || d.download_url === userProfile.cvUrl)) {
    allDocuments.unshift({
      id: "profile_cv",
      file_name: "CV_Profil_Academique.pdf",
      category: "CV",
      file_size: 350000,
      mime_type: "application/pdf",
      file_extension: ".pdf",
      storage_path: "",
      bucket: "documents",
      download_url: userProfile.cvUrl,
      uploaded_at: userProfile.updatedAt || new Date().toISOString(),
      status: "uploaded",
    });
  }

  if (userProfile?.photoUrl && !allDocuments.some((d) => d.category === "Photo d'identité" || d.download_url === userProfile.photoUrl)) {
    allDocuments.unshift({
      id: "profile_photo",
      file_name: "Photo_Profil.jpg",
      category: "Photo d'identité",
      file_size: 150000,
      mime_type: "image/jpeg",
      file_extension: ".jpg",
      storage_path: "",
      bucket: "documents",
      download_url: userProfile.photoUrl,
      uploaded_at: userProfile.updatedAt || new Date().toISOString(),
      status: "uploaded",
    });
  }

  const handleUploadClick = () => {
    setIsModalOpen(true);
    setError(null);
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > MAX_FILE_SIZE) {
      setError(`Le fichier dépasse la taille maximale de ${MAX_FILE_SIZE / 1024 / 1024} Mo`);
      return;
    }

    const fileExt = file.name.slice(file.name.lastIndexOf(".")).toLowerCase();
    if (!ALLOWED_EXTENSIONS.includes(fileExt)) {
      setError(`Type de fichier non autorisé. Types autorisés: ${ALLOWED_EXTENSIONS.join(", ")}`);
      return;
    }

    setError(null);
    uploadDocument(file);
  };

  const uploadDocument = async (file: File) => {
    setUploading(true);
    setUploadProgress(0);

    try {
      const formData = new FormData();
      formData.append("userId", userId || "");
      formData.append("category", selectedCategory);
      formData.append("file", file);

      const res = await fetch("/api/documents", {
        method: "POST",
        body: formData,
      });

      const json = await res.json();

      if (json.success) {
        setSuccess("Document téléversé avec succès !");
        setIsModalOpen(false);
        setUploadProgress(100);
        
        await fetchDocuments();
        
        setTimeout(() => {
          setUploadProgress(0);
          setSuccess(null);
        }, 2000);
      } else {
        setError(json.error || "Échec du téléversement");
      }
    } catch (e: any) {
      console.error("Upload error:", e);
      setError(e.message || "Une erreur est survenue lors du téléversement");
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  const handleDelete = async (documentId: string) => {
    if (!userId) return;

    try {
      const res = await fetch(`/api/documents?userId=${userId}&documentId=${documentId}`, {
        method: "DELETE",
      });

      const json = await res.json();

      if (json.success) {
        setDocuments((prev) => prev.filter((d) => d.id !== documentId));
        setSuccess("Document supprimé avec succès !");
        setTimeout(() => setSuccess(null), 2000);
      } else {
        setError(json.error || "Échec de la suppression");
      }
    } catch (e: any) {
      console.error("Delete error:", e);
      setError(e.message || "Une erreur est survenue lors de la suppression");
    }
  };

  const handleDownload = async (downloadUrl: string, fileName: string) => {
    try {
      const link = document.createElement("a");
      link.href = downloadUrl;
      link.download = fileName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (e) {
      console.error("Download error:", e);
      setError("Impossible de télécharger le document");
    }
  };

  const getStatusColor = (status: string): { background: string; color: string } => {
    switch (status) {
      case "uploaded":
        return { background: "var(--success-light)", color: "var(--success)" };
      case "processing":
        return { background: "var(--warning-light)", color: "var(--warning)" };
      case "error":
        return { background: "var(--alert-light)", color: "var(--alert)" };
      default:
        return { background: "var(--warm-200)", color: "var(--ink-subtle)" };
    }
  };

  return (
    <div style={{ maxWidth: "1000px", margin: "0 auto", display: "flex", flexDirection: "column", gap: "var(--space-8)", color: "var(--ink-text)" }}>
      {/* Upload Modal */}
      {isModalOpen && (
        <div style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-4)", background: "rgba(0, 0, 0, 0.5)", backdropFilter: "blur(4px)" }}>
          <div style={{ background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", maxWidth: "448px", width: "100%", boxShadow: "var(--shadow-xl)" }}>
            <h3 style={{ fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", margin: "0 0 var(--space-4)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
              <UploadCloud style={{ width: "24px", height: "24px", color: "var(--accent)" }} />
              Télécharger un document
            </h3>

            <div style={{ marginBottom: "var(--space-4)" }}>
              <label style={{ display: "block", fontSize: "var(--text-body)", fontWeight: 700, color: "var(--ink-muted)", marginBottom: "var(--space-2)" }}>
                Catégorie du document
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                style={{ width: "100%", padding: "var(--space-3)", borderRadius: "var(--radius-xl)", border: "1px solid var(--border)", background: "var(--warm-100)", color: "var(--ink-text)", fontSize: "var(--text-body)" }}
              >
                {DOCUMENT_CATEGORIES.map((category) => (
                  <option key={category} value={category}>
                    {category}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ marginBottom: "var(--space-4)" }}>
              <label style={{ display: "block", fontSize: "var(--text-body)", fontWeight: 700, color: "var(--ink-muted)", marginBottom: "var(--space-2)" }}>
                Sélectionner un fichier
              </label>
              <input
                type="file"
                ref={fileInputRef}
                onChange={handleFileChange}
                accept=".pdf,.jpg,.jpeg,.png,.webp,.doc,.docx"
                disabled={uploading}
                style={{ width: "100%", padding: "var(--space-3)", borderRadius: "var(--radius-xl)", border: "1px solid var(--border)", background: "var(--warm-100)", color: "var(--ink-text)", fontSize: "var(--text-body)" }}
              />
              <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "var(--space-1)" }}>
                Types autorisés: PDF, JPG, PNG, WebP, DOC, DOCX. Taille max: {MAX_FILE_SIZE / 1024 / 1024} Mo
              </p>
            </div>

            {uploading && (
              <div style={{ marginBottom: "var(--space-4)" }}>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: "var(--text-caption)", color: "var(--ink-subtle)", marginBottom: "var(--space-1)" }}>
                  <span>Téléversement...</span>
                  <span>{uploadProgress}%</span>
                </div>
                <div style={{ height: "8px", background: "var(--warm-200)", borderRadius: "var(--radius-full)", overflow: "hidden" }}>
                  <div
                    style={{ height: "100%", background: "var(--accent)", borderRadius: "var(--radius-full)", width: `${uploadProgress}%`, transition: "width 0.3s ease" }}
                  />
                </div>
              </div>
            )}

            {error && (
              <div style={{ padding: "var(--space-3)", background: "var(--alert-light)", border: "1px solid var(--alert)", borderRadius: "var(--radius-xl)", color: "var(--alert)", fontSize: "var(--text-body)", display: "flex", alignItems: "center", gap: "var(--space-2)", marginBottom: "var(--space-4)" }}>
                <AlertCircle style={{ width: "16px", height: "16px", flexShrink: 0 }} />
                {error}
              </div>
            )}

            <div style={{ display: "flex", gap: "var(--space-3)" }}>
              <button
                onClick={() => setIsModalOpen(false)}
                disabled={uploading}
                className="btn-secondary"
                style={{ flex: 1, padding: "var(--space-3)", borderRadius: "var(--radius-xl)", fontWeight: 700, fontSize: "var(--text-caption)" }}
              >
                Annuler
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                disabled={uploading}
                className="btn-primary"
                style={{ flex: 1, padding: "var(--space-3)", borderRadius: "var(--radius-xl)", fontWeight: 700, fontSize: "var(--text-caption)", boxShadow: "var(--shadow-md)" }}
              >
                {uploading ? (
                  <>
                    <Loader2 style={{ width: "16px", height: "16px", animation: "spin 1s linear infinite" }} />
                    <span>Téléversement...</span>
                  </>
                ) : (
                  <>
                    <UploadCloud style={{ width: "16px", height: "16px" }} />
                    <span>Télécharger</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header Banner */}
      <div style={{ background: "var(--warm-100)", backdropFilter: "blur(12px)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: "var(--space-4)" }}>
        <div>
          <h2 style={{ fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", display: "flex", alignItems: "center", gap: "var(--space-2)", margin: 0 }}>
            <FileText style={{ width: "24px", height: "24px", color: "var(--accent)" }} /> Mes Documents & Pièces Justificatives
          </h2>
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", marginTop: "var(--space-1)" }}>
            Gère tes fichiers (CV, diplômes, lettres, tests de langue) utilisés par FlyAgent pour tes candidatures.
          </p>
        </div>

        <button
          onClick={handleUploadClick}
          disabled={uploading}
          className="btn-primary"
          style={{ marginLeft: "auto", padding: "var(--space-3) var(--space-5)", borderRadius: "var(--radius-2xl)", fontWeight: 700, fontSize: "var(--text-caption)", boxShadow: "var(--shadow-md)" }}
        >
          <UploadCloud style={{ width: "16px", height: "16px" }} />
          <span>Ajouter un document</span>
        </button>
      </div>

      {success && (
        <div style={{ padding: "var(--space-4)", background: "var(--success-light)", border: "1px solid var(--success)", borderRadius: "var(--radius-xl)", color: "var(--success)", fontSize: "var(--text-body)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          <CheckCircle2 style={{ width: "20px", height: "20px", flexShrink: 0 }} />
          {success}
        </div>
      )}

      {error && !isModalOpen && (
        <div style={{ padding: "var(--space-4)", background: "var(--alert-light)", border: "1px solid var(--alert)", borderRadius: "var(--radius-xl)", color: "var(--alert)", fontSize: "var(--text-body)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          <AlertCircle style={{ width: "20px", height: "20px", flexShrink: 0 }} />
          {error}
        </div>
      )}

      {loading && allDocuments.length === 0 && (
        <div style={{ padding: "var(--space-8)", textAlign: "center" }}>
          <Loader2 style={{ width: "32px", height: "32px", margin: "0 auto", color: "var(--accent)", animation: "spin 1s linear infinite" }} />
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", marginTop: "var(--space-2)" }}>Chargement des documents...</p>
        </div>
      )}

      <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
        <h3 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)" }}>
          Documents Enregistrés ({allDocuments.length})
        </h3>

        {allDocuments.length === 0 && !loading ? (
          <div style={{ padding: "var(--space-8)", textAlign: "center", color: "var(--ink-muted)", fontSize: "var(--text-body)" }}>
            <FileText style={{ width: "48px", height: "48px", margin: "0 auto var(--space-2)", opacity: 0.5, color: "var(--ink-subtle)" }} />
            <p>Aucun document téléversé.</p>
            <p style={{ fontSize: "var(--text-caption)", marginTop: "var(--space-1)" }}>Cliquez sur "Ajouter un document" pour commencer.</p>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            {allDocuments.map((doc) => {
              const categoryColor = getCategoryColor(doc.category);
              const statusColor = getStatusColor(doc.status);
              return (
                <div
                  key={doc.id}
                  style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "var(--space-4)", borderRadius: "var(--radius-xl)", background: "var(--warm-50)", border: "1px solid var(--border)", transition: "all var(--transition-base)" }}
                  onMouseEnter={(e) => { (e.currentTarget as HTMLDivElement).style.borderColor = "var(--accent)"; }}
                  onMouseLeave={(e) => { (e.currentTarget as HTMLDivElement).style.borderColor = "var(--border)"; }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3.5)" }}>
                    <div style={{ padding: "var(--space-3)", borderRadius: "var(--radius-xl)", background: categoryColor.background, color: categoryColor.color, fontWeight: 700 }}>
                      <span style={{ fontSize: "var(--text-h2)" }}>{getCategoryIcon(doc.category)}</span>
                    </div>
                    <div>
                      <h4 style={{ fontWeight: 700, fontSize: "var(--text-caption)", color: "var(--ink-text)", margin: 0 }}>{doc.file_name}</h4>
                      <div style={{ fontSize: "11px", color: "var(--ink-muted)", marginTop: "4px" }}>
                        {doc.category} • {formatFileSize(doc.file_size)} • Ajouté le {formatDate(doc.uploaded_at)}
                        {isProfilePhoto(doc.category) && userProfile?.avatar_url === doc.download_url && (
                          <span style={{ marginLeft: "8px", color: "var(--alert)", fontWeight: 700 }}>• Photo de profil active</span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                    <span style={{ padding: "4px 10px", fontSize: "10px", fontWeight: 700, borderRadius: "var(--radius-full)", background: statusColor.background, color: statusColor.color }}>
                      {doc.status === "uploaded" ? "✓" : doc.status === "processing" ? "..." : "✗"}
                    </span>
                    
                    {doc.download_url && (
                      <button
                        onClick={() => handleDownload(doc.download_url, doc.file_name)}
                        style={{ padding: "8px", borderRadius: "var(--radius-xl)", color: "var(--accent)", border: "1px solid var(--accent-200)", background: "transparent", cursor: "pointer", transition: "all var(--transition-base)" }}
                        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "var(--accent-50)"; }}
                        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                        title="Télécharger"
                      >
                        <Download style={{ width: "16px", height: "16px" }} />
                      </button>
                    )}
                    
                    <button
                      onClick={() => handleDelete(doc.id)}
                      style={{ padding: "8px", borderRadius: "var(--radius-xl)", color: "var(--ink-subtle)", border: "1px solid var(--border)", background: "transparent", cursor: "pointer", transition: "all var(--transition-base)" }}
                      onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "var(--alert)"; (e.currentTarget as HTMLButtonElement).style.background = "var(--alert-light)"; }}
                      onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-subtle)"; (e.currentTarget as HTMLButtonElement).style.background = "transparent"; }}
                      title="Supprimer"
                    >
                      <Trash2 style={{ width: "16px", height: "16px" }} />
                    </button>
                  </div>
                </div>
              );})}
          </div>
        )}
      </div>
    </div>
  );
}
