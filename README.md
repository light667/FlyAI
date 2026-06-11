# Fly AI

## Plateforme IA mobile-first pour les bourses académiques africaines

Fly AI est une application web moderne conçue pour offrir une expérience mobile premium aux étudiants africains. Elle aide les utilisateurs à :
- trouver des bourses adaptées à leur profil,
- améliorer leurs candidatures,
- générer des lettres de motivation personnalisées,
- suivre leurs candidatures,
- obtenir des recommandations IA en temps réel.

---

## Fonctionnalités principales

- Authentification email et Google
- Onboarding et dashboard mobile-first
- Assistant IA conversationnel
- Score IA personnalisé
- Recommandations de bourses
- Suivi de candidatures
- Navigation moderne mobile / desktop
- Design UI inspiré des meilleures applications (ChatGPT, Duolingo, Revolut)

---

## Architecture technique

### Frontend
- Next.js 15 App Router
- TypeScript strict
- Tailwind CSS
- Framer Motion
- shadcn/ui
- Zustand
- React Hook Form
- Zod

### Backend
- Next.js API routes
- Firebase Auth & Firestore (configuration actuelle)
- Architecture prête à évoluer vers Supabase / PostgreSQL / Prisma

### IA
- Gestion IA via Gemini
- Support pour assistants conversationnels et génération de contenu

### Déploiement
- Vercel
- Support PWA
- Optimisation mobile
- Build production prête

---

## Installation

1. Cloner le dépôt :
   ```bash
   git clone https://github.com/light667/Projet-Fly-AI
   cd Projet-Fly-AI
   ```
2. Installer les dépendances :
   ```bash
   npm install
   ```
3. Copier le modèle d'environnement :
   ```bash
   cp .env.example .env.local
   ```
4. Ajouter les variables d'environnement nécessaires :
   - `NEXT_PUBLIC_FIREBASE_API_KEY`
   - `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
   - `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
   - `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
   - `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
   - `NEXT_PUBLIC_FIREBASE_APP_ID`
   - `NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID`
   - `GEMINI_API_KEY`

---

## Démarrage local

```bash
npm run dev
```

Ouvrir `http://localhost:3000`

---

## Build production

```bash
npm run build
npm run start
```

---

## Structure du projet

- `/app` : pages, routes et layout principal
- `/components` : composants UI réutilisables
- `/lib` : utilitaires et contextes partagés
- `/hooks` : hooks personnalisés
- `/public` : ressources publiques
- `/Landing_page` : package indépendant d'interface et composants

---

## Principes de conception

- Mobile-first
- Performance élevée
- UI immersive
- Animations fluides
- Accessibilité et contrastes soignés
- Code propre et modulaire

---

## Notes de développement

- Le monorepo inclut une application principale Next.js et un package `Landing_page` séparé.
- Le build principal exclut actuellement `Landing_page` du contrôle TypeScript afin de se concentrer sur l'application principale.
- La configuration reste prête pour une migration vers Supabase et une architecture API-first.

---

## Contribution

Toute contribution doit respecter les principes suivants :
- TypeScript strict
- Pas de code spaghetti
- Pas de clés API dans le code
- Composants clairs et testables
- États de chargement élégants
- Responsive et mobile-first

---

## Contact

Pour toute question ou amélioration, utilisez les issues du dépôt ou contactez +228 70703111