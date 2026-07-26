"use client";

import Link from "next/link";
import Image from "next/image";
import { ArrowLeft, ShieldCheck, FileText, Lock, Globe } from "lucide-react";

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-slate-50 dark:bg-[#0A0F1C] text-slate-800 dark:text-slate-100 font-sans transition-colors duration-200">
      {/* Header */}
      <header className="border-b border-slate-200 dark:border-white/10 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-3">
            <Image src="/logo.png" alt="FlyAI" width={36} height={36} className="rounded-xl shadow-sm" />
            <span className="font-extrabold text-xl tracking-tight text-slate-900 dark:text-white">
              Fly<span className="text-indigo-600 dark:text-indigo-400">AI</span>
            </span>
          </Link>

          <Link
            href="/dashboard"
            className="flex items-center gap-2 text-sm font-semibold text-indigo-600 dark:text-indigo-400 hover:underline"
          >
            <ArrowLeft className="w-4 h-4" />
            Retour à l'application
          </Link>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-3xl mx-auto px-6 py-12 space-y-8">
        <div className="text-center space-y-3">
          <div className="w-16 h-16 mx-auto rounded-2xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 flex items-center justify-center">
            <ShieldCheck className="w-8 h-8" />
          </div>
          <h1 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
            Conditions Générales d'Utilisation & Confidentialité
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">
            Dernière mise à jour : 23 Juillet 2026 • Plateforme Globale FlyAI
          </p>
        </div>

        <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/10 rounded-3xl p-6 md:p-8 space-y-6 shadow-sm">
          <section className="space-y-2">
            <h2 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <FileText className="w-5 h-5 text-indigo-500" /> 1. Présentation du Service FlyAI
            </h2>
            <p className="text-sm leading-relaxed text-slate-600 dark:text-slate-300">
              FlyAI est une plateforme intelligente dédiée à la mobilité internationale des étudiants. Elle permet la recherche, l'évaluation d'éligibilité par intelligence artificielle, le matching personnalisé et l'accompagnement à la candidature pour les bourses d'études universitaires.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Lock className="w-5 h-5 text-purple-500" /> 2. Protection et Confidentialité des Données
            </h2>
            <p className="text-sm leading-relaxed text-slate-600 dark:text-slate-300">
              Vos informations personnelles (profil académique, pays cibles, relevés de notes, CV) sont strictement confidentielles. Elles sont uniquement utilisées pour calculer vos scores de compatibilité et alimenter votre agent IA personnel FlyAgent. Aucune donnée personnelle n'est vendue à des tiers.
            </p>
          </section>

          <section className="space-y-2">
            <h2 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <Globe className="w-5 h-5 text-emerald-500" /> 3. Responsabilités et Candidatures
            </h2>
            <p className="text-sm leading-relaxed text-slate-600 dark:text-slate-300">
              FlyAI s'efforce de maintenir des informations exactes sur les bourses et leurs critères d'éligibilité. Les étudiants demeurent toutefois responsables de vérifier les délais et de transmettre leurs dossiers finaux aux organismes officiels ou via les outils FlyAgent.
            </p>
          </section>
        </div>
      </main>
    </div>
  );
}
