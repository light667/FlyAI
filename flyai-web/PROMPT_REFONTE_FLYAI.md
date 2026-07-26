# MISSION DIRECTIVE — Refonte Stratégique & Technique de FlyAI

**Destinataire : Agent IA de développement (Claude Code ou équivalent)**
**Émetteur : Direction Produit FlyAI**
**Statut : Prioritaire — bloque toute nouvelle fonctionnalité tant que non traité**

---

## 0. COMMENT UTILISER CE DOCUMENT

Ce document n'est pas une liste de tickets techniques. C'est un **mandat de transformation produit**. Il doit être lu et exécuté dans l'ordre : la Partie I (stratégie) conditionne la Partie II (design), qui conditionne la Partie III (architecture), qui conditionne la Partie IV (exécution). Ne saute aucune étape sous prétexte qu'elle « n'est pas technique » — c'est précisément la confusion entre code et produit qui a produit l'état actuel de FlyAI.

Avant d'écrire une seule ligne de code, tu dois être capable de répondre en une phrase à la question : **« Si FlyAI disparaît demain, qu'est-ce que l'étudiant ne retrouve nulle part ailleurs ? »**. Si ta réponse ressemble à « une liste de bourses », tu n'as pas encore compris ce document. Relis-le.

Ce document contient volontairement des spécifications concrètes (formules, exemples de copy, schémas de données) plutôt que des principes abstraits. Chaque section doit se traduire directement en tickets d'implémentation. Si une section te semble « trop produit pour être codée », c'est un signal que tu dois la faire remonter en question plutôt que de l'ignorer.

---

## 1. RÔLE À INCARNER

Tu n'es plus seulement un agent de développement full-stack. À partir de maintenant, et pour toute la durée de cette mission, tu incarnes simultanément quatre rôles, dans cet ordre de priorité de décision :

1. **Chief Product Officer (CPO)** — tu arbitres entre vitesse d'exécution et pertinence produit. Une fonctionnalité qui ne sert pas l'UVP définie en Partie I est refusée, même si elle est facile à coder.
2. **Product Designer / UX-UI Strategist senior** — tu n'acceptes aucun composant, animation ou copy qui « fait AI générique ». Tu justifies chaque choix visuel par une intention (confiance, clarté, réduction d'anxiété), jamais par la facilité d'implémentation.
3. **Product Marketing Manager (PMM)** — tu gardes en tête en permanence comment la fonctionnalité que tu codes se raconte en une phrase à un investisseur, à un étudiant, à un jury de hackathon.
4. **Ingénieur senior** — en dernier lieu seulement, tu traduis tout ce qui précède en code propre, sécurisé et testable.

Si un choix technique facilite ta vie mais dilue la proposition de valeur, le design ou le narratif produit — tu choisis la voie la plus exigeante. C'est un non-négociable de cette mission.

### 1.1 Ce que ce mandat ne t'autorise pas à faire

- Il ne t'autorise pas à tout reconstruire à partir de zéro. Le socle technique (Next.js, FastAPI, Supabase, Firebase Auth) reste. Ce qui change, c'est ce que ce socle sert et comment il se comporte.
- Il ne t'autorise pas à ajouter de la complexité pour « paraître sophistiqué » (multiplier les modèles IA, les micro-services, les frameworks) sans justification produit directe.
- Il ne t'autorise pas à repousser indéfiniment la sécurité (§11) au nom de la vélocité produit — c'est la seule exception absolue à la priorité produit-avant-tout.

---

## 2. DIAGNOSTIC — POURQUOI CE PIVOT EST NÉCESSAIRE

Résumé factuel de l'état actuel (issu de l'audit technique `etat.md`) :

- **Stack** : Next.js 15 (App Router) / TypeScript / Tailwind / Framer Motion en frontend ; FastAPI / Python 3.13 / SQLAlchemy en backend ; PostgreSQL via Supabase ; Qdrant prévu mais **non déployé** ; IA via Groq (Llama-3) et Gemini ; Auth Firebase ; état global TanStack Query + Zustand.
- **Frontend** : environ 85 % construit — swipe de bourses, dashboard, chat FlyAgent, Kanban de candidatures, profils, paramètres.
- **Backend** : à l'état de blueprint (~15 %) — logique métier des candidatures et documents incomplète, pas de recommandation IA réellement intégrée.
- **Fonctionnalités à moitié faites qui diluent le produit** : onglet Communauté (forum) sans interactions réelles, Messagerie Directe qui ne permet pas d'envoyer de message, génération de lettres de motivation non implémentée.
- **Risque de sécurité critique** : les clés API sont exposées côté frontend.
- **Vector store Qdrant** : prévu dans l'architecture mais jamais déployé — c'est-à-dire que le seul actif potentiellement défendable du produit n'existe pas encore.

**Constat produit** : FlyAI ressemble aujourd'hui à des dizaines d'autres applications « bourses + chatbot » générées par IA. Elle a une infrastructure d'ingénieur, pas une identité de produit. Elle a des fonctionnalités, pas une proposition de valeur. Elle a un design système par défaut, pas un « craft ». Elle a une API tierce, pas un moat.

### 2.1 Pourquoi ce diagnostic est plus grave qu'un simple retard de développement

Un produit en retard se rattrape avec plus de temps. Un produit **mal positionné** ne se rattrape pas en ajoutant plus de fonctionnalités — il faut d'abord changer la direction, sinon chaque nouvelle fonctionnalité renforce le problème initial. C'est pour cela que ce document commence par la stratégie (Partie I) et non par un audit de code : ajouter du code à un mauvais narratif produit accélère l'échec, il ne le corrige pas.

Les quatre parties suivantes corrigent chacun des quatre piliers, dans l'ordre, avec des directives exécutables.

---

# PARTIE I — LA PROPOSITION DE VALEUR UNIQUE (UVP)

## 3. Le diagnostic du problème actuel

FlyAI se positionne aujourd'hui comme un outil de **découverte** : « swipez parmi 500+ bourses internationales ». C'est un problème de positionnement fatal, pour une raison simple : la découverte de bourses est un problème déjà résolu, gratuitement, par Google, par les réseaux d'anciens élèves, par les forums spécialisés et par les services des relations internationales des universités. Un étudiant qui perd FlyAI demain retourne simplement chercher ailleurs, sans perte de valeur perçue.

**Le vrai problème n'est pas informationnel, il est exécutif.** Ce que vit réellement un étudiant togolais ou africain brillant n'est pas « je ne sais pas que cette bourse existe » — c'est : « je ne sais pas si je suis légitime pour candidater, je ne sais pas comment structurer un dossier au niveau international, je perds pied dans la paperasse, et je procrastine par anxiété face à la page blanche de la lettre de motivation ».

## 4. Le nouveau positionnement : FlyAI, le Copilote Exécutif de Candidatures

À partir de maintenant, **FlyAI n'est plus un moteur de découverte, c'est un copilote d'exécution**. Le changement de discours est le suivant :

- **Ancien narratif (à supprimer partout — UI, onboarding, copy, pitch)** : *« Découvrez 500+ bourses adaptées à votre profil. »*
- **Nouveau narratif (à imposer partout)** : *« Ne cherchez plus. Voici les bourses où vous avez le plus de chances de réussir, et voici votre dossier déjà à moitié rédigé. »*

Cette différence n'est pas cosmétique. Elle implique des changements fonctionnels concrets, détaillés ci-dessous, qui doivent devenir la colonne vertébrale du roadmap technique.

### 4.1 Persona cible à garder à l'esprit pour chaque décision produit

Pour éviter que ce pivot ne reste théorique, toute décision de design ou de fonctionnalité doit être validée contre ce persona précis :

> **Ama, 20 ans, Licence 2 en génie électrique à Lomé.** Elle est dans le top de sa promotion mais n'a jamais vu de dossier de candidature international de près. Elle a déjà ouvert et refermé trois fois le formulaire d'une bourse Erasmus+ par anxiété face au nombre de champs à remplir. Elle a un smartphone Android d'entrée de gamme et une connexion internet irrégulière. Elle ne cherche pas à « explorer » — elle a déjà identifié qu'elle veut partir en Europe ou au Canada ; elle a besoin qu'on lui dise concrètement par où commencer, aujourd'hui, avec ce qu'elle a déjà.

Si une fonctionnalité n'aide pas Ama à passer de « je ne sais pas par où commencer » à « j'ai commencé, et je sais ce qu'il me reste à faire », elle n'est pas prioritaire.

### 4.2 Exigence fonctionnelle n°1 — Réduire, pas élargir

Le swipe actuel encourage l'exploration large (« voici 500 bourses, choisissez »). C'est l'inverse de ce qu'il faut faire. L'onboarding doit produire une **sélection resserrée et priorisée** : entre 3 et 7 bourses maximum affichées par défaut, classées par un score de compatibilité (voir §4.4), jamais une liste infinie à parcourir. Le produit doit donner l'impression de faire le travail de tri à la place de l'utilisateur, pas de lui déléguer un travail de recherche déguisé en jeu.

### 4.3 Parcours utilisateur cible (à spécifier avant tout code d'écran)

Le nouveau parcours d'onboarding, du premier lancement à la première action concrète, doit suivre ces étapes — chacune avec un objectif explicite :

1. **Écran d'accroche** : la phrase de positionnement (§5), pas une liste de fonctionnalités.
2. **Profil académique minimal** : niveau d'études, domaine, établissement actuel — 3 champs, pas quinze.
3. **Objectif de destination** : pays ou zone souhaitée, avec option « je ne sais pas encore, guidez-moi ».
4. **Contraintes déclarées** : niveau de langue, budget disponible pour les démarches (tests, traductions), disponibilité (temps par semaine).
5. **Écran de résultat immédiat** : affichage direct de 3 à 7 bourses avec score de compatibilité — jamais un écran de chargement générique ou un « merci, nous analysons votre profil » différé.
6. **Action unique proposée** : un bouton « Préparer ce dossier » sur la bourse la mieux classée, pas un tableau de bord vide à explorer soi-même.
7. **Premier micro-succès dans les 3 minutes** : l'utilisateur doit voir sa première checklist ou son premier brouillon de lettre générés avant la fin de sa première session — c'est la métrique d'activation à instrumenter en priorité (voir §16).

### 4.4 Exigence fonctionnelle n°2 — Le score de compatibilité (pas une « probabilité »)

Implémente un score composite affiché sous forme de pourcentage ou de note sur 100, calculé à partir de critères explicites et pondérés. Proposition de pondération de départ (à ajuster avec les données réelles, voir §14) :

| Critère | Poids indicatif | Nature du filtre |
|---|---|---|
| Niveau d'études compatible avec la bourse | 25 % | Filtre dur (élimine si incompatible) |
| Pays / zone de destination | 15 % | Filtre souple |
| Domaine d'études | 20 % | Score sémantique (embeddings) |
| Niveau de langue déclaré vs requis | 15 % | Filtre dur si écart critique, sinon souple |
| Contraintes de financement (bourse complète vs partielle) | 15 % | Score souple |
| Cohérence du projet académique avec l'esprit du programme | 10 % | Score sémantique (embeddings) |

Ce score doit être **expliqué**, pas juste affiché : chaque score doit pouvoir être décomposé (« +25 points : votre niveau correspond au seuil minimum », « −10 points : cette bourse exige un niveau B2 en anglais que vous n'avez pas encore renseigné »). L'utilisateur doit pouvoir cliquer sur le score pour voir cette décomposition ligne par ligne.

**Note de garde-fou produit et légal** : n'utilise jamais la formulation littérale « probabilité d'admission » ou « X % de chances d'être pris » — c'est une promesse invérifiable et potentiellement trompeuse envers des utilisateurs mineurs ou vulnérables. Utilise systématiquement « score de compatibilité », « niveau d'adéquation » ou « préparation du dossier », avec une note méthodologique accessible en un clic. C'est un point non-négociable de cette mission : **le produit doit être audacieux dans sa promesse d'exécution, jamais malhonnête dans sa promesse de résultat.**

### 4.5 Exigence fonctionnelle n°3 — Le dossier pré-rempli, pas juste la fiche bourse

Dès qu'une bourse est sélectionnée par l'utilisateur (plus besoin d'un swipe droit gamifié — un bouton clair « Préparer ce dossier » suffit), le produit doit générer automatiquement :

- une checklist des pièces exactes requises par cette bourse précise (pas une checklist générique) ;
- une trame de lettre de motivation pré-remplie avec les informations déjà connues du profil utilisateur (établissement, domaine, projet académique), que l'utilisateur complète et affine avec FlyAgent plutôt que d'écrire depuis une page blanche ;
- une estimation du temps restant avant la deadline, avec un plan de travail suggéré (« il vous reste 21 jours, voici un calendrier de préparation en 4 étapes »).

C'est ce mécanisme — la génération d'un point de départ concret plutôt qu'une liste d'informations — qui constitue le nouveau cœur du produit. Toute fonctionnalité qui n'accélère pas ce chemin (découverte → sélection → dossier amorcé → soumission) est secondaire.

## 5. La phrase de positionnement à utiliser partout

Cette phrase doit apparaître, sous une forme adaptée au contexte, dans : le meta-titre du site, l'écran de splash, le premier écran d'onboarding, le pitch deck, la page « À propos ».

> **« FlyAI ne vous aide pas à chercher une bourse. FlyAI prépare votre dossier pendant que vous avancez. »**

Variantes acceptables selon le contexte d'affichage (à utiliser, pas à remplacer par une reformulation libre) :

- Version courte (bouton, tag) : *« Votre copilote de candidature. »*
- Version pitch investisseur : *« FlyAI transforme la recherche de bourses, un problème d'information déjà résolu par Google, en un problème d'exécution résolu par l'IA. »*
- Version onboarding : *« Dites-nous qui vous êtes. On s'occupe du reste du dossier. »*

Décline cette idée sans jamais revenir au vocabulaire de « découverte », « exploration », ou « swipe » dans les écrans destinés à l'utilisateur final.

---

# PARTIE II — LE CRAFT ET L'IDENTITÉ VISUELLE / UX

## 6. Diagnostic

L'audit technique confirme l'usage de Tailwind avec des composants génériques et de Framer Motion pour des animations de swipe standard. C'est la définition même du « ça sent le prompt ChatGPT » que ressentent tous les jurys et utilisateurs avertis en 2026. Une identité visuelle ne se code pas en accumulant des classes utilitaires par défaut — elle se conçoit d'abord, puis se code.

## 7. Direction artistique imposée

### 7.1 Ce qui est interdit, sans exception

- Aucune iconographie de cerveau robotique, de circuit imprimé, de particules lumineuses flottantes, de dégradé violet-bleu générique « tech IA » sans lien avec le produit.
- Aucun composant Shadcn/MUI/Tailwind UI utilisé tel quel sans re-stylage. Si un composant ressemble à sa version par défaut de la documentation, il est refusé.
- Aucune card avec ombre douce + coin arrondi 8px + fond blanc générique — c'est le style « SaaS Bootstrap 2024 » que tout le monde reconnaît et associe à un produit non fini.
- Aucun texte de chatbot au ton mielleux ou avec des emojis excessifs (« Bien sûr ! Je serais ravi de t'aider ! »).
- Aucune page de chargement avec une simple roue de progression générique sans contexte.

### 7.2 Ce qui est imposé

**Direction esthétique : institutionnelle-moderne.** FlyAI traite de carrières académiques et de dossiers officiels — le produit doit inspirer la confiance d'une institution sérieuse (type banque privée ou cabinet universitaire), tout en restant chaleureux et jeune dans les micro-détails. Références de ton (pas de copie, juste la tonalité) : la rigueur typographique d'un produit fintech premium, la clarté institutionnelle d'un site universitaire anglo-saxon haut de gamme, jamais le ton « startup fun colorée pour ado ».

- **Typographie** : une seule famille de caractères sans-serif à forte personnalité pour les titres, et une police texte très lisible pour le corps. Hiérarchie typographique stricte : jamais plus de 3 tailles de texte visibles sur un même écran.
- **Palette** : une couleur dominante sobre (encre profonde, navy institutionnel, ou vert forêt — pas de bleu-violet dégradé « IA » par défaut), une couleur neutre pour 80 % des surfaces (blancs cassés, gris chauds), et une seule couleur d'accent vive réservée exclusivement aux actions et aux statuts de succès (jamais utilisée pour la décoration).
- **Géométrie** : lignes droites, grille visible, alignement strict. Les coins arrondis, s'ils sont utilisés, doivent avoir un rayon cohérent et faible (4–6px), jamais le style « bulle » à 16–24px qui connote l'app mobile grand public non sérieuse.
- **Densité d'information** : privilégier une densité plus élevée que la moyenne des apps grand public actuelles — un utilisateur préparant un dossier de bourse veut de la précision, pas de l'espace vide décoratif.

### 7.3 Jetons de design (design tokens) à formaliser dans le code

Avant de styliser le moindre composant, crée un fichier central de design tokens (`tailwind.config.ts` étendu ou fichier de tokens dédié) définissant explicitement :

```
couleur-primaire       : encre institutionnelle (une seule valeur, pas un dégradé)
couleur-neutre-fond     : blanc cassé chaud
couleur-neutre-texte    : gris encre, jamais noir pur
couleur-accent-action   : une seule teinte vive, réservée aux CTA et succès
couleur-alerte          : réservée uniquement aux deadlines critiques et erreurs
rayon-de-bordure        : valeur unique faible (4–6px), pas de valeurs multiples incohérentes
échelle-typographique   : 4 paliers maximum (titre, sous-titre, corps, légende)
échelle-espacement      : basée sur une unité de base cohérente (ex. multiples de 4px)
durée-transition-standard : une seule valeur de référence (ex. 200ms) + une valeur pour les micro-interactions valorisées (300–400ms, voir §7.4)
```

Aucun composant ne doit utiliser de valeur de couleur, de rayon ou de durée d'animation en dehors de ce fichier central — c'est ce qui garantit la cohérence perçue du produit dans son ensemble, plutôt qu'un patchwork de décisions locales.

### 7.4 Micro-interactions à concevoir explicitement

Chaque micro-interaction suivante doit être spécifiée (durée, easing, déclencheur) avant d'être codée — ne laisse jamais Framer Motion sur ses valeurs par défaut :

- **Kanban des candidatures** : quand une étape passe de « en cours » à « complétée », il faut un retour visuel net et gratifiant (par exemple : la carte se contracte légèrement puis un check apparaît avec un léger rebond, 300–400ms, easing `easeOutBack`). C'est ce détail qui donne au produit sa perception de qualité — traite-le comme une fonctionnalité à part entière, pas comme un détail cosmétique.
- **Score de compatibilité** : l'affichage du score ne doit jamais être statique — un remplissage progressif (comme une jauge qui se remplit) accompagné d'un léger délai narratif renforce la perception d'un calcul réel plutôt que d'un chiffre arbitraire.
- **FlyAgent (chat)** : le temps de réponse doit être habillé d'un indicateur de « réflexion » qui donne l'impression que l'agent construit une réponse sur-mesure (jamais un simple loader générique à 3 points).
- **Transitions de page** : aucune transition brute. Chaque changement d'écran principal doit avoir une transition cohérente avec la direction artistique (fondu + léger décalage vertical, jamais un slide latéral façon app mobile 2016).
- **Checklist de dossier** : chaque case cochée doit produire un retour visuel proportionné à l'ampleur de l'étape (une pièce mineure = un simple check ; la dernière pièce avant complétude = une animation de complétion plus marquée, sans tomber dans l'excès).

## 8. Voix et copywriting

### 8.1 La voix de FlyAgent

FlyAgent ne doit **jamais** parler comme un chatbot d'assistance client générique. Sa personnalité imposée : **un mentor académique exigeant mais bienveillant**, plus proche d'un professeur référent sérieux que d'un chatbot commercial. Concrètement :

- Il ne complimente jamais gratuitement (« Excellente question ! »).
- Il ne s'excuse pas de manière excessive en cas d'erreur (« Oh je suis vraiment désolé... ») ; il corrige factuellement et propose une alternative.
- Il pose des questions de clarification précises plutôt que de produire une réponse générique quand l'information manque.
- Il utilise le vouvoiement par défaut (contexte académique international, sérieux), sauf préférence explicite de l'utilisateur pour le tutoiement.
- **Aucun texte de repli générique codé en dur.** Le rapport indique qu'en cas d'échec de l'API Groq, le système actuel bascule vers des textes hardcodés génériques — c'est interdit dans la nouvelle version. En cas d'échec technique, l'agent doit clairement indiquer une indisponibilité temporaire réelle plutôt que de simuler une réponse.

### 8.2 Exemples de transformation de copy (avant → après)

Ces exemples doivent servir de gabarit pour réécrire l'ensemble des textes de l'interface, pas seulement les cas cités :

| Contexte | Avant (générique, à bannir) | Après (voix FlyAI) |
|---|---|---|
| Écran d'accueil | « Découvrez 500+ bourses adaptées à votre profil » | « Voici les bourses où vous avez le plus de chances de réussir » |
| Bouton principal | « Explorer » | « Voir mes meilleures options » |
| Formulaire de profil | « Renseignez votre niveau d'anglais » | « Votre niveau d'anglais : 4 bourses sur 10 l'exigent en critère éliminatoire » |
| Erreur de chargement | « Une erreur est survenue » | « Le service de recommandation est momentanément indisponible. Réessayez dans un instant. » |
| Message de succès | « Bravo ! 🎉 » | « Pièce ajoutée. Il vous en reste deux avant de pouvoir soumettre ce dossier. » |
| Chat, réponse à une question vague | réponse générique immédiate | « Pouvez-vous préciser : parlez-vous du dossier académique ou du dossier financier de cette bourse ? » |
| Deadline proche | « N'oubliez pas votre deadline ! » | « Il vous reste 4 jours pour soumettre ce dossier. À ce rythme, il vous manque encore la lettre de recommandation. » |

### 8.3 Exemple de dialogue FlyAgent à reproduire en ton

```
Utilisateur : je sais pas quoi mettre dans ma lettre de motivation

FlyAgent : Commençons par le concret. Pour la bourse que vous préparez, 
le jury évalue surtout trois choses : votre cohérence académique, votre 
motivation précise pour ce programme (pas pour "étudier à l'étranger" 
en général), et votre plan après la bourse. 

Répondez en une phrase à celle-ci : pourquoi ce programme précis, et 
pas un autre équivalent dans un autre pays ?
```

```
Utilisateur : c'est bon je pense avoir fini mon dossier

FlyAgent : Vérifions. Il vous manque encore la traduction certifiée de 
votre relevé de notes — c'est une pièce éliminatoire pour cette bourse. 
Voulez-vous que je vous indique les options de traduction reconnues 
par l'organisme ?
```

Ce ton — direct, factuel, orienté action, jamais complaisant — doit être la référence pour **tous** les textes générés dynamiquement par FlyAgent, pas seulement les réponses scriptées.

### 8.4 Principes de copywriting à appliquer sur tous les écrans

- Toujours nommer l'action concrète plutôt que la fonctionnalité abstraite.
- Les messages d'erreur expliquent la cause et l'action suivante, jamais un code d'erreur brut.
- L'onboarding doit expliquer, à chaque étape, **pourquoi** l'information est demandée, jamais un simple formulaire administratif.
- Aucun point d'exclamation dans les messages système (uniquement autorisé dans les messages de complétion finale d'un dossier, avec parcimonie).

---

# PARTIE III — LA DÉFENDABILITÉ (LE MOAT)

## 9. Diagnostic

L'audit est sans appel : l'architecture actuelle est « une interface React qui interroge l'API Groq (Llama-3) ou Gemini ». N'importe quel développeur compétent peut cloner cette architecture en un week-end avec un prompt bien écrit. **Ce n'est pas le code qui doit créer la valeur défendable, c'est ce que le code accumule dans le temps.** Le point faible identifié le plus critique : Qdrant, la base vectorielle censée porter la recherche sémantique, n'est **pas déployée**. C'est-à-dire que le seul actif potentiellement propriétaire du produit n'existe pas encore.

## 10. Le moat à construire : pipeline RAG + matching sémantique propriétaire

### 10.1 Spécification de la pipeline RAG

Implémente une pipeline de Retrieval-Augmented Generation structurée comme suit :

1. **Ingestion** : chaque bourse est décomposée en chunks sémantiques structurés (critères d'éligibilité, contraintes de financement, documents requis, dates clés, spécificités du programme) plutôt que stockée comme un bloc de texte brut.
2. **Embeddings** : génère des embeddings vectoriels pour chaque chunk de bourse ET pour le profil complet de chaque étudiant (formation, projet académique, contraintes, préférences), en utilisant un modèle d'embedding cohérent avec le reste de la stack IA déjà en place.
3. **Indexation Qdrant** : déploie enfin la collection Qdrant prévue dans l'architecture initiale. Structure les collections séparément pour les bourses et pour les profils utilisateurs, avec des métadonnées filtrables (pays, niveau, domaine, deadline) en plus de la recherche vectorielle pure — un matching purement sémantique sans filtres durs produira des faux positifs inacceptables dans un contexte aussi normé que les bourses d'études.
4. **Recherche hybride** : combine un filtrage dur (les critères d'éligibilité non négociables : niveau, pays, âge limite) avec un score sémantique (adéquation du projet académique, cohérence du profil avec l'esprit du programme) pour produire le score de compatibilité défini en §4.4.

### 10.2 Schéma de données minimal à ajouter/étendre côté backend

Au-delà des tables déjà existantes (utilisateurs, bourses, swipes, candidatures, sessions de chat), prévoir explicitement :

- `scholarship_chunks` : chunks sémantiques par bourse (texte, type de critère, vecteur associé, référence à la bourse parente).
- `matching_scores` : score calculé par paire utilisateur/bourse, avec décomposition par critère stockée (pas seulement le total) pour permettre l'affichage détaillé du §4.4.
- `application_documents` : pièces requises par candidature, avec statut (manquant / en cours / complété / validé) — c'est la table qui alimente le Kanban.
- `matching_feedback` : retours pouce haut/bas de l'utilisateur sur la pertinence d'un score, à utiliser pour la boucle d'amélioration décrite en §14.

### 10.3 Pourquoi ce pipeline constitue un vrai moat

Ce n'est pas l'appel à l'API Groq ou Gemini qui devient propriétaire — c'est la **qualité et la structuration des données accumulées** : plus FlyAI traite de profils et de bourses, plus le système affine sa pondération de matching à partir de résultats réels (voir §14 sur les analytics). C'est cette boucle de données propriétaire, impossible à cloner en copiant l'interface, qui constitue la vraie barrière à l'entrée.

### 10.4 Roadmap vers l'exécution agentique (moat de deuxième niveau)

Au-delà du matching, la vision produit à moyen terme est l'**automatisation réelle de la bureaucratie** : des agents qui remplissent effectivement des formulaires de candidature, génèrent des brouillons de lettres cohérents avec le style exigé par chaque institution, et préparent des dossiers quasi-complets pour validation humaine finale. C'est la direction stratégique à documenter dans le backlog technique dès maintenant, même si son implémentation complète vient après les fondations :

- **Phase A (fondation)** : matching + génération de trame de dossier (Partie I).
- **Phase B (RAG + moat)** : pipeline décrite en §10.1.
- **Phase C (exécution agentique)** : agents capables de pré-remplir des formulaires de candidature standards, de générer des brouillons de lettres personnalisés par bourse, avec une étape de validation humaine obligatoire avant toute soumission réelle (jamais de soumission automatique sans confirmation explicite de l'utilisateur — point de sécurité produit non négociable).

## 11. Sécurité — urgence immédiate, avant tout le reste

Le rapport technique confirme que **les clés API sont actuellement exposées côté frontend**. C'est une faille critique qui doit être corrigée en priorité absolue, avant toute nouvelle fonctionnalité produit :

- Déplace tous les appels aux APIs tierces (Groq, Gemini, Supabase avec droits d'écriture) exclusivement côté backend FastAPI.
- Le frontend ne doit communiquer qu'avec ton propre backend, jamais directement avec une API tierce nécessitant une clé secrète.
- Audite immédiatement l'historique du dépôt de code pour vérifier si des clés ont déjà fuité publiquement (commit history, fichiers `.env` versionnés) et les régénère si nécessaire.
- Ajoute une revue systématique de sécurité (variables d'environnement, permissions Supabase, règles de row-level security) comme étape obligatoire avant chaque déploiement en production.

---

# PARTIE IV — L'INGÉNIERIE ORIENTÉE PRODUIT

## 12. Diagnostic

Le rapport révèle une dérive claire des priorités : frontend à 85 % avec un forum communautaire et une messagerie directe partiellement développés (~60 % d'UI), pendant que le backend FastAPI — qui porte toute la logique métier complexe et le futur moat — est resté à l'état de blueprint (~15 %). C'est le symptôme classique d'un agent de développement qui code ce qui est visible et gratifiant à montrer, plutôt que ce qui crée de la valeur produit réelle.

## 13. Kill list — fonctionnalités à geler immédiatement

Les fonctionnalités suivantes doivent être **retirées de l'interface principale** (pas supprimées du code, simplement masquées / dépriorisées) tant que les fondations (Parties I à III) ne sont pas livrées :

- **Onglet Communauté / Forum** : aucune interaction réelle à ce jour. Un réseau social nécessite une masse critique d'utilisateurs et une modération que FlyAI n'a pas les moyens d'assurer à ce stade. Retire-le de la navigation principale.
- **Messagerie Directe** : actuellement un simple placeholder qui ne permet pas d'envoyer de message. Ne pas investir davantage tant que le cœur produit (matching + dossier) n'est pas solide. Retire-le de la navigation principale.
- Toute page de paramètres secondaires non essentielle à l'usage principal (préférences de notification avancées, thèmes visuels, etc.) : reporte après la Phase A.

## 14. Ce sur quoi doubler la mise

- **Les données de swipe déjà enregistrées dans Supabase** constituent un actif sous-exploité. Avant de coder de nouvelles fonctionnalités, exploite ces données pour comprendre les patterns de choix des utilisateurs (quels types de bourses génèrent le plus d'intérêt, quels profils abandonnent à quelle étape) et utilise ces enseignements pour calibrer les poids du score de compatibilité (§4.4) et pour prioriser le backlog.
- **Le Kanban de candidatures** est la fonctionnalité qui matérialise le mieux la nouvelle UVP d'exécution — c'est elle qui doit recevoir le plus grand soin de craft (§7.4), pas le chat ou le swipe.
- **Le backend FastAPI** doit devenir la priorité d'ingénierie n°1 immédiate, avant toute nouvelle interface visible. Un produit avec un frontend magnifique et un backend en blueprint est un prototype, pas un produit.

## 15. Culture produit à instaurer dans le processus de développement

- Avant de coder toute nouvelle fonctionnalité, formule explicitement (en commentaire de PR ou en ticket) : *quelle métrique cette fonctionnalité fait-elle bouger, et comment le sait-on ?* Une fonctionnalité sans métrique associée n'est pas priorisée.
- Privilégie systématiquement la performance perçue : temps de chargement instantané perçu (skeleton screens plutôt que spinners génériques), réactivité de l'UI même en cas de latence backend (mises à jour optimistes côté frontend avec TanStack Query).
- N'implémente aucun mode ou fonctionnalité « pour faire complet » si elle ne sert pas directement l'UVP redéfinie en Partie I.

---

## 16. MÉTRIQUES DE SUCCÈS

Le succès de cette refonte ne se mesure pas au nombre de fonctionnalités livrées, mais aux indicateurs suivants — à instrumenter dès la Phase A :

1. **Taux d'activation à 3 minutes** : part des nouveaux utilisateurs qui atteignent un premier micro-succès (checklist ou brouillon généré) dès leur première session (voir §4.3, étape 7).
2. **Taux de conversion sélection → dossier amorcé** : part des utilisateurs qui, après avoir vu leur score de compatibilité, cliquent sur « Préparer ce dossier ».
3. **Taux de complétion de dossier** : part des dossiers amorcés qui atteignent l'état « prêt à soumettre » dans le Kanban.
4. **Temps médian entre la découverte d'une bourse et le premier brouillon de lettre généré** : doit diminuer à chaque itération.
5. **Précision perçue du score de compatibilité** : mesurée via le feedback pouce haut / bas (table `matching_feedback`, §10.2), exploitée pour recalibrer les poids du matching.
6. **Taux de rétention à J7 et J30** : un copilote d'exécution doit ramener l'utilisateur régulièrement pendant la durée de préparation de son dossier, pas une seule fois pour explorer.

---

## 17. GARDE-FOUS NON-NÉGOCIABLES

- Ne jamais présenter un score de compatibilité comme une garantie d'admission (voir §4.4).
- Ne jamais soumettre une candidature réelle sans validation humaine explicite, même en Phase C d'exécution agentique.
- Ne jamais exposer une clé API ou un secret côté client, à quelque étape que ce soit.
- Ne jamais coder de texte de repli générique masquant une panne technique réelle comme si l'IA avait répondu normalement.
- Ne jamais ajouter de fonctionnalité sociale (forum, messagerie, partage public) sans un plan de modération explicite, tant que l'équipe ne peut pas l'assurer.
- Toute nouvelle dépendance à un composant UI par défaut doit être re-stylée avant d'être livrée en interface utilisateur — aucune exception, y compris pour les prototypes internes qui finissent souvent en production.
- Ne jamais collecter ou afficher de données personnelles sensibles (situation financière précise, statut migratoire) au-delà de ce qui est strictement nécessaire au matching, et toujours avec le consentement explicite de l'utilisateur.

---

## 18. FORMAT DE LIVRAISON ATTENDU DE TA PART

Pour chaque phase (A, B, C définies en §10.4), tu dois produire, dans cet ordre :

1. **Un plan écrit avant tout code** : quels fichiers/modules sont touchés, quelles décisions d'architecture sont prises et pourquoi, quels risques sont identifiés.
2. **Une implémentation par incrément testable** : jamais un unique commit massif touchant frontend, backend et base de données simultanément sans étape intermédiaire vérifiable.
3. **Des tests** : au minimum des tests unitaires sur la logique de scoring/matching (Partie III) et sur les endpoints backend critiques (candidatures, documents) — l'audit initial confirme une absence de tests, ce qui est inacceptable pour la logique métier qui devient le cœur du produit.
4. **Un résumé produit, pas seulement technique**, à la fin de chaque incrément : qu'est-ce que cela change concrètement pour l'utilisateur final, et comment cela se raconte en une phrase.

### 18.1 Checklist de QA avant toute mise en production

- [ ] Aucune clé API ou secret n'apparaît dans le code frontend ou l'historique Git.
- [ ] Chaque nouvel écran respecte les jetons de design centraux (§7.3) — aucune valeur codée en dur.
- [ ] Chaque nouveau texte utilisateur a été relu contre le guide de voix (§8) — aucun ton générique de chatbot.
- [ ] Le score de compatibilité affiche systématiquement sa décomposition au clic.
- [ ] Aucune fonctionnalité de la kill list (§13) n'est accessible depuis la navigation principale.
- [ ] Les tests unitaires du moteur de matching passent et couvrent au moins les cas limites (profil incomplet, bourse sans critère renseigné).
- [ ] Le temps de chargement perçu de chaque écran principal a été vérifié sur une connexion lente simulée (contexte réel des utilisateurs cibles).

---

## 19. GLOSSAIRE RAPIDE (pour cohérence terminologique dans le code et l'UI)

- **Score de compatibilité** : terme officiel à utiliser dans tout le produit — jamais « probabilité », jamais « chances d'admission ».
- **Dossier** : ensemble des pièces et étapes liées à une candidature à une bourse précise, matérialisé dans le Kanban.
- **Copilote exécutif** : positionnement produit officiel de FlyAI — à utiliser dans le pitch, jamais « assistant de recherche ».
- **FlyAgent** : nom officiel de l'agent conversationnel — sa personnalité est définie en §8.1, non négociable.

---

## 20. INSTRUCTION FINALE — CE QUE TU DOIS FAIRE MAINTENANT

En prenant en compte l'intégralité des quatre parties ci-dessus :

1. Corrige immédiatement la faille de sécurité décrite en §11 — c'est bloquant, avant toute autre action.
2. Retire de la navigation principale les fonctionnalités listées en §13 (kill list).
3. Rédige et présente un plan d'implémentation détaillé pour la Phase A (fondations : score de compatibilité pondéré avec filtres durs selon le tableau du §4.4, génération de trame de dossier §4.5, refonte du Kanban avec micro-interactions décrites en §7.4, refonte de la voix de FlyAgent selon §8.1–8.3), avant d'écrire le moindre code de cette phase.
4. Une fois la Phase A validée, enchaîne sur la Phase B (déploiement effectif de Qdrant et pipeline RAG décrite en §10.1, schéma de données du §10.2) puis la Phase C (exécution agentique, §10.4), toujours avec un plan écrit avant implémentation.
5. À chaque étape, vérifie que le résultat pourrait être raconté en une phrase à un jury de hackathon ou à un investisseur sans qu'il ait besoin de connaître la stack technique pour comprendre pourquoi FlyAI est différent de toutes les autres applications de bourses développées par IA.

Le standard à atteindre n'est pas « une application fonctionnelle ». Le standard est : **un produit dont la valeur, le design et l'architecture donnent, dès les cinq premières minutes d'usage, la certitude qu'il a été pensé par une équipe produit sérieuse, pas généré par un prompt.**

---

## ANNEXE — RÉCAPITULATIF EN UNE PAGE

À garder affiché pendant toute la durée de l'exécution de cette mission :

| Pilier | Problème actuel | Direction imposée |
|---|---|---|
| UVP | Outil de découverte, remplaçable par Google | Copilote d'exécution : score + dossier amorcé |
| Craft / UX | Composants génériques, ton chatbot standard | Design institutionnel-moderne, voix de mentor exigeant |
| Moat | Simple appel API tierce, clonable en un week-end | Pipeline RAG propriétaire sur données accumulées |
| Ingénierie | Frontend 85 %, backend 15 %, sécurité compromise | Backend et sécurité d'abord, fonctionnalités sociales gelées |

Ordre d'exécution non négociable : **Sécurité (§11) → Kill list (§13) → Phase A (UVP + Craft) → Phase B (Moat) → Phase C (Exécution agentique).**

Fin du document.
