"use client";

import { useState } from "react";
import { UserProfile } from "@/types";
import { FileText, UploadCloud, Trash2, CheckCircle2, Download, ExternalLink, ShieldCheck } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

interface DocItem {
  id: string;
  name: string;
  category: string;
  size: string;
  date: string;
  url?: string;
}

export default function DocumentsTab({ userId, userProfile }: Props) {
  const [documents, setDocuments] = useState<DocItem[]>([
    {
      id: "1",
      name: "CV_Academique_FlyAI.pdf",
      category: "Curriculum Vitae",
      size: "245 KB",
      date: "23 Juil 2026",
    },
    {
      id: "2",
      name: "Releves_de_notes_Licence.pdf",
      category: "Relevé de notes",
      size: "1.2 MB",
      date: "15 Juin 2026",
    },
    {
      id: "3",
      name: "Attestation_TOEFL_B2.pdf",
      category: "Certificat de Langue",
      size: "820 KB",
      date: "10 Mai 2026",
    },
  ]);

  const [uploading, setUploading] = useState(false);

  const handleUpload = () => {
    setUploading(true);
    setTimeout(() => {
      setDocuments((prev) => [
        {
          id: Date.now().toString(),
          name: "Nouveau_Document_Etudiant.pdf",
          category: "Pièce Justificative",
          size: "512 KB",
          date: new Date().toLocaleDateString("fr-FR"),
        },
        ...prev,
      ]);
      setUploading(false);
    }, 1200);
  };

  const handleDelete = (id: string) => {
    setDocuments((prev) => prev.filter((d) => d.id !== id));
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 text-slate-800 dark:text-slate-200">
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
          onClick={handleUpload}
          disabled={uploading}
          className="flex items-center gap-2 px-5 py-3 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md transition-all disabled:opacity-50"
        >
          <UploadCloud className={`w-4 h-4 ${uploading ? "animate-spin" : ""}`} />
          <span>{uploading ? "Envoi..." : "Ajouter un document"}</span>
        </button>
      </div>

      {/* Documents List */}
      <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/5 p-6 rounded-3xl space-y-4">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base border-b border-slate-100 dark:border-white/5 pb-3">
          Documents Enregistrés ({documents.length})
        </h3>

        {documents.length === 0 ? (
          <div className="p-8 text-center text-slate-400 text-xs">Aucun document téléversé.</div>
        ) : (
          <div className="space-y-3">
            {documents.map((doc) => (
              <div
                key={doc.id}
                className="flex items-center justify-between p-4 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/5 hover:border-indigo-500 transition-all"
              >
                <div className="flex items-center gap-3.5">
                  <div className="p-3 rounded-xl bg-indigo-500/10 text-indigo-500 font-bold">
                    <FileText className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="font-bold text-xs text-slate-900 dark:text-white">{doc.name}</h4>
                    <div className="text-[11px] text-slate-400 mt-0.5">
                      {doc.category} • {doc.size} • Ajouté le {doc.date}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2">
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
