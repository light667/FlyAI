# CORRECTIF URGENT — Réparer l'exécution ratée de la Phase A (FlyAI)

**Destinataire : Agent IA de développement (même agent que la mission précédente)**
**Émetteur : Direction Produit FlyAI**
**Statut : Bloquant absolu — l'application est actuellement dans un état pire qu'avant la mission précédente**

---

## 0. CE QUI S'EST PASSÉ

La mission précédente (`PROMPT_REFONTE_FLYAI.md`) demandait un pivot stratégique et un durcissement du craft, du moat et de l'ingénierie. Ce qui a été livré à la place : des pages supprimées, des fonctionnalités existantes cassées, des bugs de base de données bloquants en production, et une reskin cosmétique du chat sans aucune des capacités réelles demandées.

**Ce correctif part d'un principe simple que la mission précédente n'a pas assez explicité : transformer un produit ne veut jamais dire régresser sur ce qui fonctionnait déjà.** Ce document corrige cet oubli et traite, dans l'ordre, chaque régression et chaque bug rapporté.

Preuve technique de l'état actuel (extrait des logs `npm run dev` fournis) :

```
Error fetching applications: {
  code: 'PGRST200',
  message: "Could not find a relationship between 'applications' and 'bourses' in the schema cache",
  hint: "Perhaps you meant 'scholarships' instead of 'bourses'."
}
GET /api/applications?userId=... 500 in 877ms

Error upserting profile: {
  code: 'PGRST204',
  message: "Could not find the 'avatar_url' column of 'profiles' in the schema cache"
}
```

Ces deux erreurs à elles seules confirment que **la page Candidatures (Kanban) est intégralement cassée en production** (erreur 500 systématique, aucune candidature ne peut se charger) et que **la mise à jour de profil échoue silencieusement côté base de données**. Ce n'est pas un détail secondaire — c'est la fonctionnalité cœur de toute la Phase A qui est en panne.

---

## 1. RÈGLE N°0, ABSOLUE, AU-DESSUS DE TOUT LE RESTE

**Avant toute chose : aucune page, aucun écran, aucune fonctionnalité existante et fonctionnelle ne doit être supprimée ou dégradée sans autorisation explicite écrite.**

La mission précédente demandait de **geler** deux fonctionnalités précises (forum, messagerie directe) — geler signifie les retirer de la navigation principale, pas supprimer ou casser tout le reste par effet de bord. Si tu as interprété une demande de refonte comme une autorisation à reconstruire des pages entières depuis zéro, c'est l'erreur qui a produit l'état actuel. Corrige ce réflexe maintenant :

- Toute page qui existait et fonctionnait avant la mission précédente (notamment **la page de remplissage / complétion de profil**, indispensable au matching) doit être restaurée immédiatement si elle a disparu ou a été cassée.
- Chaque modification future doit être un diff ciblé sur un fichier ou un composant précis, jamais une réécriture large « pendant que j'y suis ».
- Si une page semble redondante avec la nouvelle vision produit, tu proposes sa dépréciation dans un plan écrit et tu attends une validation avant de la toucher — tu ne la supprimes jamais unilatéralement.

---

## 2. BUGS BLOQUANTS CONFIRMÉS PAR LES LOGS — À CORRIGER EN PREMIER

### 2.1 Erreur 500 systématique sur `/api/applications` — incohérence de nommage `bourses` vs `scholarships`

Le message d'erreur est explicite : le code (probablement une requête Supabase avec `.select('*, bourses(*)')` ou une relation déclarée dans le client) référence une table ou une relation nommée `bourses`, alors que la table réelle s'appelle `scholarships`. Supabase te donne littéralement la réponse dans le `hint`.

**Action exacte à effectuer :**

1. Cherche dans tout le code backend et frontend toute occurrence de `bourses` utilisée comme nom de table, de relation Supabase, ou de clé étrangère (`select`, `.from('bourses')`, `foreignTable: 'bourses'`, types générés, etc.).
2. Remplace systématiquement par `scholarships` — **choisis un seul nom canonique dans toute la base de code, en anglais puisque c'est déjà la convention du reste du schéma (`applications`, `profiles`)**. Ne mélange jamais un nom de table en français et le reste du schéma en anglais.
3. Vérifie que la clé étrangère existe réellement en base : `applications.scholarship_id` doit référencer `scholarships.id` avec une contrainte `FOREIGN KEY` déclarée en migration SQL, pas seulement supposée côté code.
4. Régénère le cache de schéma PostgREST après toute modification de schéma (`NOTIFY pgrst, 'reload schema';` ou équivalent selon ta configuration Supabase) — une partie du problème vient probablement d'un cache de schéma non rafraîchi après une migration.
5. Régénère les types TypeScript Supabase (`supabase gen types typescript`) pour que le frontend ne référence plus l'ancien nom nulle part, y compris dans les types.

**Critère d'acceptation** : `GET /api/applications?userId=...` doit retourner un `200` avec la liste réelle des candidatures de l'utilisateur, plus aucune trace de `bourses` dans le code ou les logs.

### 2.2 Erreur `avatar_url column not found` sur la mise à jour de profil

Le code tente d'écrire une colonne `avatar_url` dans la table `profiles`, mais cette colonne n'existe pas dans le schéma réel (ou le cache de schéma est désynchronisé).

**Action exacte à effectuer :**

1. Vérifie si la colonne `avatar_url` doit réellement exister (si le profil est censé stocker une photo). Si oui, écris une migration SQL explicite `ALTER TABLE profiles ADD COLUMN avatar_url text;` et applique-la.
2. Si la colonne n'est pas nécessaire pour le MVP actuel, retire la référence à `avatar_url` du payload envoyé par le endpoint `/api/profile` plutôt que de laisser un échec silencieux en production.
3. Dans tous les cas, **le endpoint ne doit plus renvoyer un `200` factice quand l'upsert échoue côté base** (le log montre `POST /api/profile 200` alors que l'erreur d'upsert est bien présente juste au-dessus — c'est un mensonge silencieux à l'utilisateur). Fais remonter un code d'erreur réel si l'écriture en base échoue, avec un message clair côté frontend.

**Critère d'acceptation** : plus aucune erreur `PGRST204` dans les logs lors de la sauvegarde de profil, et le endpoint ne retourne `200` que si l'écriture en base a réellement réussi.

### 2.3 Audit général obligatoire avant de continuer

Avant de traiter la moindre régression fonctionnelle listée en Partie 3, exécute `npm run dev` (ou l'équivalent), navigue sur chaque page principale de l'application, et confirme dans les logs qu'il n'y a **plus aucune erreur 500 ni erreur Supabase silencieuse**. Documente ce contrôle dans ton plan avant de passer à la suite.

---

## 3. RÉGRESSIONS FONCTIONNELLES À RESTAURER

### 3.1 Page de remplissage de profil disparue

C'est la régression la plus grave signalée : la page de complétion de profil après inscription — qui alimente directement le score de compatibilité — a disparu ou a été cassée.

**Action exacte :**
- Restaure cette page si elle a été supprimée, ou corrige-la si elle est cassée.
- Elle doit collecter au minimum : niveau d'études, domaine, établissement, pays de destination souhaité, niveau de langue, contraintes de financement — c'est-à-dire exactement les champs décrits dans le parcours d'onboarding de la mission précédente (§4.3 du document stratégique).
- Elle doit être accessible à tout moment depuis les paramètres, pas seulement lors de l'inscription — un utilisateur doit pouvoir mettre à jour son profil quand sa situation change, et le score de compatibilité de toutes ses bourses doit se recalculer en conséquence.
- Vérifie qu'aucune autre page (mentionnée par l'utilisateur comme « plusieurs pages » cassées) n'a subi le même sort. Fais un inventaire complet des routes de l'application (`app/` dans Next.js) et compare-le à l'inventaire d'avant la mission précédente si tu as accès à l'historique Git. Toute route disparue sans justification documentée doit être restaurée.

### 3.2 Mode sombre et mode clair rendent une interface identique

C'est un défaut d'implémentation des jetons de design demandés en §7.3 de la mission précédente : les tokens de couleur doivent réellement changer de valeur selon le thème actif, pas simplement exister en théorie.

**Action exacte :**
1. Vérifie que le mécanisme de thème (probablement une classe `dark` sur `<html>` avec Tailwind, ou un `ThemeProvider`) est réellement branché à des variables CSS distinctes pour chaque thème.
2. Vérifie que **chaque composant** utilise ces variables (`bg-background`, `text-foreground`, etc. dans le système de tokens Tailwind) plutôt que des couleurs codées en dur (`bg-white`, `text-black`) qui ignorent le thème actif — c'est la cause la plus probable du bug : des couleurs figées quelque part dans les composants empêchent le changement visuel malgré un toggle qui fonctionne techniquement.
3. Teste visuellement les deux modes sur chaque écran principal (dashboard, profil, candidatures, chat, documents) et confirme une différence de fond, de texte et de couleurs d'accent clairement visible entre les deux modes.

### 3.3 Nom d'utilisateur générique (« Étudiant ») au lieu du prénom réel

**Action exacte :**
- Récupère le prénom (ou le nom d'affichage) renseigné à l'inscription ou dans le profil, et utilise-le systématiquement dans toute l'interface (message d'accueil, dashboard, messages de FlyAgent) à la place de tout texte générique du type « Étudiant », « Utilisateur », etc.
- Si le prénom n'est pas encore renseigné (compte tout juste créé), affiche un état transitoire explicite le temps que l'utilisateur complète son profil (§3.1) — jamais un nom générique permanent qui donne l'impression que l'app ne connaît pas son propre utilisateur.
- Vérifie que ce prénom est bien lu depuis la table `profiles` (ou l'objet Firebase Auth `displayName` si c'est la source de vérité) et non codé en dur quelque part dans un composant.

### 3.4 Documents : placeholders non cliquables au lieu d'un vrai système

C'est une régression sur une fonctionnalité qui devait pourtant être renforcée par la mission précédente (§4.5, dossier pré-rempli). Actuellement, la section Documents affiche des noms de documents par défaut qui ne sont même pas cliquables — c'est pire qu'un état vide honnête.

**Action exacte, les deux mécanismes suivants sont obligatoires et non substituables l'un à l'autre :**

1. **Import réel de documents** : l'utilisateur doit pouvoir uploader un fichier réel (relevé de notes, passeport, diplôme...) associé à une pièce précise de sa checklist. Implémente le upload vers le stockage Supabase (bucket dédié, avec règles de sécurité limitant l'accès au propriétaire du document) et lie chaque fichier uploadé à la ligne correspondante dans `application_documents`.
2. **Génération assistée des documents essentiels** : pour les documents qui peuvent être générés (lettre de motivation, CV académique), FlyAgent doit produire un brouillon réel basé sur les informations du profil de l'utilisateur (établissement, domaine, projet académique) et sur les critères de la bourse ciblée — pas un texte générique, et certainement pas un placeholder statique.
3. Chaque ligne de document dans l'interface doit être un élément interactif réel : cliquable, avec un statut visuel clair (manquant / en cours d'upload / uploadé / généré par IA en attente de relecture / validé), jamais une simple liste de texte statique.

**Critère d'acceptation** : un utilisateur peut uploader un vrai fichier PDF depuis son profil et le voir apparaître associé à la bonne pièce, et peut demander à FlyAgent de générer un brouillon de lettre de motivation qui apparaît ensuite comme pièce « générée, à valider » dans le même système — pas dans une fenêtre de chat déconnectée.

---

## 4. FLYAGENT : LE VRAI PROBLÈME EST L'ABSENCE DE CAPACITÉS RÉELLES, PAS SEULEMENT LE TON

Le rapport indique que FlyAgent est aujourd'hui indiscernable d'un chatbot généraliste. La mission précédente demandait un ton spécifique (§8.1–8.3 du document stratégique) — mais un ton ne suffit pas si l'agent n'a aucune capacité fonctionnelle différenciante. Voici ce qui manque concrètement.

### 4.1 Absence de personnalité réellement appliquée

Si la voix définie précédemment (mentor exigeant, jamais complaisant, jamais de compliment gratuit, aucun texte de repli générique) n'apparaît pas dans les réponses actuelles, c'est que le system prompt envoyé au modèle (Groq/Llama-3 ou Gemini selon le routage) n'a probablement jamais été mis à jour, ou que l'agent a seulement modifié quelques libellés d'interface sans toucher au prompt système réel qui pilote la génération.

**Action exacte** : localise le fichier ou la fonction qui construit le system prompt envoyé au LLM pour FlyAgent, et remplace-le entièrement par une version qui encode explicitement : le rôle (mentor académique, jamais chatbot commercial), les interdits (compliments gratuits, excuses excessives, emojis), le vouvoiement par défaut, et l'obligation de poser une question de clarification plutôt que de répondre de façon générique quand une information manque. Ce prompt système doit être un fichier versionné et documenté, pas une chaîne de caractères éparpillée dans le code.

### 4.2 Aucune capacité de recherche web réelle

C'est le manque le plus critique signalé : quand un utilisateur demande des informations sur une bourse précise, FlyAgent ne peut pas aller chercher l'information à jour sur le web — il ne peut répondre qu'à partir de ce qui est déjà dans la base de données interne ou halluciner à partir des connaissances générales du modèle sous-jacent, ce qui est dangereux dans un contexte où les dates de deadline et les critères changent chaque année.

**Action exacte :**
1. Intègre un outil de recherche web (function calling / tool use) dans l'appel au LLM utilisé par FlyAgent — que ce soit via les capacités natives de tool use de Groq/Gemini ou via une API de recherche tierce (Tavily, Bing Search API, ou équivalent) branchée comme fonction disponible pour le modèle.
2. Le comportement attendu : si la question porte sur une bourse déjà présente et à jour dans la base interne (`scholarships`), FlyAgent répond directement à partir de cette source, plus rapide et plus fiable. Si la question porte sur une bourse absente de la base, ou si l'utilisateur demande explicitement une vérification d'actualité (dates, montants, conditions récentes), FlyAgent déclenche une recherche web et **cite la source** dans sa réponse.
3. Ne jamais présenter une information issue d'une recherche web comme si elle venait de la base de données interne, et inversement — la distinction doit être visible pour l'utilisateur (par exemple un petit badge « vérifié via le web » ou une source en pied de réponse).

### 4.3 Formatage des messages cassé et gestion des accents défaillante

Deux problèmes distincts, à corriger séparément.

**Formatage cassé** : si les réponses de FlyAgent affichent du texte brut avec des symboles Markdown non interprétés (`**gras**`, `- listes`, `# titres` affichés tels quels), c'est que le frontend affiche la réponse du modèle comme du texte brut au lieu de la faire passer par un vrai moteur de rendu Markdown. **Action exacte** : utilise un composant de rendu Markdown (`react-markdown` ou équivalent déjà présent dans l'écosystème Next.js) pour afficher toutes les réponses de FlyAgent, avec une feuille de style cohérente avec les jetons de design définis dans la mission précédente (§7.3) — pas le style par défaut de la librairie.

**Accents mal gérés** : si des caractères comme « é », « à », « ç » s'affichent de façon corrompue (mojibake du type `Ã©` à la place de `é`), c'est un problème d'encodage UTF-8 non déclaré quelque part dans la chaîne de traitement. **Action exacte** :
1. Vérifie que chaque réponse API du backend FastAPI déclare explicitement `Content-Type: application/json; charset=utf-8`.
2. Vérifie qu'aucune étape du pipeline (appel au LLM, stockage en base, transmission au frontend) ne force un encodage ASCII ou ne fait de conversion d'encodage implicite (erreur classique en Python : lecture ou écriture de fichier sans `encoding="utf-8"` explicite).
3. Vérifie la configuration de la base PostgreSQL (encodage de la base et des colonnes texte doit être `UTF8`, ce qui est le défaut Supabase mais peut être écrasé par une mauvaise configuration de connexion).
4. Teste explicitement avec des messages contenant des accents et des caractères spéciaux français avant de considérer ce point comme résolu.

### 4.4 « Postuler avec FlyAgent » ne sert à rien

Le rapport est clair : cette fonctionnalité se contente de donner des informations générales sur toutes les bourses existantes, puis laisse l'utilisateur livré à lui-même. C'est l'inverse exact de l'UVP définie dans la mission précédente (le copilote d'exécution, pas un moteur d'information générale).

**Action exacte — refonte complète du flux, pas un ajustement de copy :**

1. Le bouton « Postuler avec FlyAgent » doit **toujours** être attaché à une bourse précise déjà identifiée (jamais un point d'entrée générique vers le chat sans contexte). Le clic doit ouvrir une session de chat qui a déjà en contexte : le profil complet de l'utilisateur et les critères exacts de la bourse sélectionnée.
2. Dès l'ouverture, FlyAgent doit produire immédiatement, sans que l'utilisateur ait à demander quoi que ce soit : la checklist des pièces exactes requises pour cette bourse précise (pas une liste générique), et une première ébauche des sections principales de la lettre de motivation à partir du profil connu.
3. La conversation qui suit doit rester ancrée sur cette candidature précise (affiner la lettre, clarifier une pièce manquante, calculer le temps restant avant la deadline) — jamais dériver vers une discussion générale sur les bourses disponibles, qui relève d'un autre écran (la liste de recommandations, pas ce flux de candidature).
4. Chaque sortie produite par FlyAgent dans ce flux (checklist, brouillon de lettre) doit s'intégrer directement dans le système de documents décrit en §3.4 — jamais rester uniquement dans l'historique de chat, où l'utilisateur devrait recopier manuellement.

**Critère d'acceptation** : un utilisateur qui clique sur « Postuler avec FlyAgent » depuis une bourse précise voit apparaître, en moins de 10 secondes, une checklist spécifique à cette bourse et un brouillon de lettre déjà amorcé — jamais un message générique du type « voici des informations sur les bourses disponibles ».

---

## 5. PROTOCOLE DE VÉRIFICATION AVANT DE DÉCLARER CE CORRECTIF TERMINÉ

Ne considère aucun point ci-dessus comme résolu tant que tu n'as pas vérifié, dans cet ordre :

1. `npm run dev` (ou build de production) démarre sans erreur, et aucune route ne renvoie de `500`.
2. Chaque page qui existait avant la mission précédente est accessible et fonctionnelle, y compris la page de complétion de profil.
3. Le mode sombre et le mode clair produisent visuellement deux interfaces different (capture d'écran ou description explicite des différences si tu ne peux pas produire de capture).
4. Le prénom réel de l'utilisateur de test apparaît dans l'interface, pas un texte générique.
5. Un document peut être réellement uploadé et apparaît associé à la bonne pièce ; un brouillon de lettre peut être réellement généré par FlyAgent et apparaît dans le système de documents.
6. FlyAgent répond avec un ton conforme à la voix définie (§4.1), déclenche une recherche web sur une question test portant sur une bourse absente de la base, et cite sa source.
7. Un message de test contenant des accents (« Merci pour votre réponse détaillée sur les critères d'éligibilité ») s'affiche correctement, sans corruption de caractères, et avec le Markdown correctement rendu (pas de `**` visibles).
8. Le flux « Postuler avec FlyAgent » sur une bourse test produit immédiatement une checklist spécifique et un brouillon de lettre, sans dérive vers une réponse générique.

---

## 6. INSTRUCTION FINALE

Traite ce document comme un correctif, pas comme une nouvelle mission créative : **l'objectif n'est pas d'innover davantage, c'est de rendre fonctionnel ce qui a été cassé et de livrer réellement ce qui avait été demandé et seulement esquissé en surface.** Corrige dans l'ordre des sections ci-dessus (bugs bloquants d'abord, puis régressions, puis capacités FlyAgent), produis un plan écrit avant chaque correctif comme l'exige la mission précédente, et ne passe à l'étape suivante qu'après avoir validé le protocole de vérification de la Partie 5 pour l'étape en cours.
