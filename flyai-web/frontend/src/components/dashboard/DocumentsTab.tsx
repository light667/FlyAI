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

function getCategoryColor(category: string): string {
  const colors: Record<string, string> = {
    CV: "bg-indigo-500/10 text-indigo-500",
    "Relevé de notes": "bg-emerald-500/10 text-emerald-500",
    Diplôme: "bg-amber-500/10 text-amber-500",
    "Certificat de Langue": "bg-rose-500/10 text-rose-500",
    "Lettre de motivation": "bg-cyan-500/10 text-cyan-500",
    "Lettre de recommandation": "bg-violet-500/10 text-violet-500",
    Passeport: "bg-sky-500/10 text-sky-500",
    "Photo d'identité": "bg-pink-500/10 text-pink-500",
    Autre: "bg-slate-500/10 text-slate-500",
  };
  return colors[category] || "bg-slate-500/10 text-slate-500";
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

  const getStatusColor = (status: string): string => {
    switch (status) {
      case "uploaded":
        return "bg-emerald-500/10 text-emerald-600";
      case "processing":
        return "bg-amber-500/10 text-amber-600";
      case "error":
        return "bg-rose-500/10 text-rose-600";
      default:
        return "bg-slate-500/10 text-slate-600";
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 text-slate-800 dark:text-slate-200">
      {/* Upload Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-md flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-white/5 rounded-3xl p-6 max-w-md w-full shadow-2xl">
            <h3 className="text-xl font-extrabold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
              <UploadCloud className="w-6 h-6 text-indigo-500" />
              Télécharger un document
            </h3>

            <div className="mb-4">
              <label className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2">
                Catégorie du document
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-white/5 bg-white dark:bg-slate-900/60 text-slate-800 dark:text-slate-200 font-medium"
              >
                {DOCUMENT_CATEGORIES.map((category) => (
                  <option key={category} value={category} className="dark:bg-slate-800">
                    {category}
                  </option>
                ))}
              </select>
            </div>

            <div className="mb-4">
              <label className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2">
                Sélectionner un fichier
              </label>
              <input
                type="file"
                ref={fileInputRef}
                onChange={handleFileChange}
                accept=".pdf,.jpg,.jpeg,.png,.webp,.doc,.docx"
                disabled={uploading}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-white/5 bg-white dark:bg-slate-900/60 text-slate-800 dark:text-slate-200 file:mr-4 file:py-2 file:px-4 file:rounded-l-2xl file:border-0 file:bg-indigo-500/10 file:text-indigo-600 hover:file:bg-indigo-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
              />
              <p className="text-[10px] text-slate-400 mt-1">
                Types autorisés: PDF, JPG, PNG, WebP, DOC, DOCX. Taille max: {MAX_FILE_SIZE / 1024 / 1024} Mo
              </p>
            </div>

            {uploading && (
              <div className="mb-4">
                <div className="flex justify-between text-xs text-slate-400 mb-1">
                  <span>Téléversement...</span>
                  <span>{uploadProgress}%</span>
                </div>
                <div className="h-2 bg-slate-200 dark:bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-indigo-500 rounded-full transition-all"
                    style={{ width: `${uploadProgress}%` }}
                  />
                </div>
              </div>
            )}

            {error && (
              <div className="p-3 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-600 text-sm flex items-center gap-2 mb-4">
                <AlertCircle className="w-4 h-4 flex-shrink-0" />
                {error}
              </div>
            )}

            <div className="flex gap-3">
              <button
                onClick={() => setIsModalOpen(false)}
                disabled={uploading}
                className="flex-1 p-3 rounded-2xl border border-slate-200 dark:border-white/5 text-slate-700 dark:text-slate-300 font-bold text-xs hover:bg-slate-100 dark:hover:bg-white/5 transition-all disabled:opacity-50"
              >
                Annuler
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                disabled={uploading}
                className="flex-1 p-3 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md transition-all disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {uploading ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Téléversement...</span>
                  </>
                ) : (
                  <>
                    <UploadCloud className="w-4 h-4" />
                    <span>Télécharger</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header Banner */}
      <div className="bg-white dark:bg-slate-900/60 backdrop-blur-xl border border-slate-200 dark:border-white/5 p-6 rounded-3xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
            <FileText className="w-6 h-6 text-indigo-500" /> Mes Documents & Pièces Justificatives
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            Gère tes fichiers (CV, diplômes, lettres, tests de langue) utilisés par FlyAgent pour tes candidatures.
          </p>
        </div>

        <button
          onClick={handleUploadClick}
          disabled={uploading}
          className="flex items-center gap-2 px-5 py-3 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md transition-all disabled:opacity-50"
        >
          <UploadCloud className={`w-4 h-4 ${uploading ? "animate-spin" : ""}`} />
          <span>Ajouter un document</span>
        </button>
      </div>

      {success && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-emerald-600 text-sm flex items-center gap-2">
          <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
          {success}
        </div>
      )}

      {error && !isModalOpen && (
        <div className="p-4 bg-rose-500/10 border border-rose-500/20 rounded-xl text-rose-600 text-sm flex items-center gap-2">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          {error}
        </div>
      )}

      {loading && documents.length === 0 && (
        <div className="p-8 text-center">
          <Loader2 className="w-8 h-8 animate-spin mx-auto text-indigo-500" />
          <p className="text-sm text-slate-400 mt-2">Chargement des documents...</p>
        </div>
      )}

      <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/5 p-6 rounded-3xl space-y-4">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base border-b border-slate-100 dark:border-white/5 pb-3">
          Documents Enregistrés ({documents.length})
        </h3>

        {documents.length === 0 && !loading ? (
          <div className="p-8 text-center text-slate-400 text-sm">
            <FileText className="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p>Aucun document téléversé.</p>
            <p className="text-xs mt-1">Cliquez sur "Ajouter un document" pour commencer.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {documents.map((doc) => (
              <div
                key={doc.id}
                className="flex items-center justify-between p-4 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/5 hover:border-indigo-500 transition-all"
              >
                <div className="flex items-center gap-3.5">
                  <div className={`p-3 rounded-xl ${getCategoryColor(doc.category)} font-bold`}>
                    <span className="text-lg">{getCategoryIcon(doc.category)}</span>
                  </div>
                  <div>
                    <h4 className="font-bold text-xs text-slate-900 dark:text-white">{doc.file_name}</h4>
                    <div className="text-[11px] text-slate-400 mt-0.5">
                      {doc.category} • {formatFileSize(doc.file_size)} • Ajouté le {formatDate(doc.uploaded_at)}
                      {isProfilePhoto(doc.category) && userProfile?.avatar_url === doc.download_url && (
                        <span className="ml-2 text-pink-500 font-bold">• Photo de profil active</span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <span className={`px-2.5 py-1 text-[10px] font-black rounded-full ${getStatusColor(doc.status)}`}>
                    {doc.status === "uploaded" ? "✓" : doc.status === "processing" ? "..." : "✗"}
                  </span>
                  
                  {doc.download_url && (
                    <button
                      onClick={() => handleDownload(doc.download_url, doc.file_name)}
                      className="p-2 rounded-xl text-indigo-500 hover:text-indigo-600 hover:bg-indigo-500/10 transition-all"
                      title="Télécharger"
                    >
                      <Download className="w-4 h-4" />
                    </button>
                  )}
                  
                  <button
                    onClick={() => handleDelete(doc.id)}
                    className="p-2 rounded-xl text-slate-400 hover:text-rose-500 hover:bg-rose-500/10 transition-all"
                    title="Supprimer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
