# Architecture FlyAI

## 1. Vue d’ensemble

FlyAI est une application Flutter cross-platform orientée étudiant, conçue pour aider à découvrir, évaluer et candidater à des bourses. Le produit suit un modèle de parcours simple :

- découvrir des opportunités de bourses,
- matcher avec les plus pertinentes,
- gérer ses candidatures,
- obtenir de l’aide via un assistant IA.

Le projet combine aujourd’hui trois dimensions :

1. une application mobile/web Flutter,
2. une couche de données et de matching via Supabase,
3. un pipeline de collecte de données de bourses via des scripts Python.

---

## 2. Architecture générale

L’architecture actuelle suit une logique de type Clean-ish Feature-First, avec une séparation claire entre :

- la couche présentation (screens, widgets),
- la couche application (providers, notifiers),
- la couche accès aux données (repositories, services),
- la couche infrastructure (Firebase, Supabase, IA, stockage local).

```text
UI (Screens / Widgets)
  ↓
Providers / State Notifiers
  ↓
Repositories
  ↓
Services & External APIs
  ↓
Firebase / Supabase / AI / Local Storage
```

---

## 3. Structure du dépôt

```text
/
├── flyai/                  # application Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/           # services transverses, router, theme, providers
│   │   ├── features/       # modules métier par fonctionnalité
│   │   ├── pages/          # pages d’entrée legacy / wrappers
│   │   └── widgets/        # widgets partagés
│   ├── pubspec.yaml
│   └── README.md
├── data/                   # données brutes et consolidées
├── scripts/                # pipeline de scraping / normalisation / import
└── architecture.md         # document d’architecture
```

---

## 4. Composants principaux du frontend

### 4.1 Démarrage de l’application

Le point d’entrée principal est [flyai/lib/main.dart](flyai/lib/main.dart).

Le bootstrap fait trois choses :

- initialiser Flutter et les bindings,
- initialiser Firebase,
- initialiser Supabase,
- lancer l’application avec Riverpod et GoRouter.

### 4.2 Routage

Le routage est centralisé dans [flyai/lib/core/router/app_router.dart](flyai/lib/core/router/app_router.dart).

Il sert à :

- gérer les routes principales (splash, onboarding, auth, profile setup, home, settings),
- contrôler l’accès selon l’état d’authentification,
- exposer un router configuré via Riverpod.

### 4.3 Gestion d’état

L’application utilise Riverpod comme moteur principal.

Patterns observés :

- `Provider` pour des dépendances simples,
- `FutureProvider` pour des données asynchrones,
- `StreamProvider` pour l’état d’authentification,
- `AsyncNotifier` / `StateNotifier` pour les écrans et flux métier complexes.

Exemples :

- authentification : [flyai/lib/features/auth/providers/auth_provider.dart](flyai/lib/features/auth/providers/auth_provider.dart)
- profils : [flyai/lib/features/profile/providers/profile_provider.dart](flyai/lib/features/profile/providers/profile_provider.dart)
- bourses : [flyai/lib/features/scholarships/providers/scholarship_provider.dart](flyai/lib/features/scholarships/providers/scholarship_provider.dart)
- assistant IA : [flyai/lib/features/ai_assistant/providers/chat_provider.dart](flyai/lib/features/ai_assistant/providers/chat_provider.dart)

---

## 5. Organisation fonctionnelle

Le code est organisé par feature, ce qui est adapté à l’échelle actuelle.

### 5.1 Authentification

Dossier : [flyai/lib/features/auth](flyai/lib/features/auth)

Responsabilités :

- inscription / connexion email,
- connexion Google / Apple,
- reset de mot de passe,
- gestion de la session utilisateur.

Le flux repose sur :

- [flyai/lib/core/services/auth_service.dart](flyai/lib/core/services/auth_service.dart)
- [flyai/lib/features/auth/providers/auth_provider.dart](flyai/lib/features/auth/providers/auth_provider.dart)

### 5.2 Onboarding

Dossier : [flyai/lib/features/onboarding](flyai/lib/features/onboarding)

Responsabilités :

- écran de splash,
- écran d’onboarding,
- transition initiale vers la bonne route.

### 5.3 Profil utilisateur

Dossier : [flyai/lib/features/profile](flyai/lib/features/profile)

Responsabilités :

- création / mise à jour du profil,
- upload de photo et CV,
- stockage des préférences académiques et géographiques.

### 5.4 Bourses et matching

Dossier : [flyai/lib/features/scholarships](flyai/lib/features/scholarships)

Responsabilités :

- récupération des bourses depuis Supabase,
- calcul du score de compatibilité,
- affichage du détail d’une bourse,
- logique de swipe.

Le cœur métier du matching repose sur :

- [flyai/lib/features/scholarships/repositories/scholarship_repository.dart](flyai/lib/features/scholarships/repositories/scholarship_repository.dart)
- [flyai/lib/features/scholarships/services/matching_engine.dart](flyai/lib/features/scholarships/services/matching_engine.dart)

### 5.5 Swipe

Dossier : [flyai/lib/features/swipe](flyai/lib/features/swipe)

Responsabilités :

- enregistrer les actions like / skip / super like,
- alimenter la logique de recommandation.

### 5.6 Dashboard et shell principal

Dossier : [flyai/lib/features/dashboard](flyai/lib/features/dashboard)

Responsabilités :

- shell d’application avec navigation par onglets,
- intégration des écrans principaux : swipe, communauté, IA, candidatures, profil.

### 5.7 Assistant IA

Dossier : [flyai/lib/features/ai_assistant](flyai/lib/features/ai_assistant)

Responsabilités :

- conversation avec l’IA,
- persistance des messages,
- contexte de bourses et d’orientation académique.

### 5.8 Candidatures

Dossier : [flyai/lib/features/applications](flyai/lib/features/applications)

Responsabilités :

- suivi des candidatures,
- checklist de documents,
- progression d’avancement.

---

## 6. Couche données et services transverses

### 6.1 Services centraux

Le dossier [flyai/lib/core/services](flyai/lib/core/services) contient des services transverses :

- [flyai/lib/core/services/auth_service.dart](flyai/lib/core/services/auth_service.dart) : encapsulation Firebase Auth,
- [flyai/lib/core/services/supabase_service.dart](flyai/lib/core/services/supabase_service.dart) : accès centralisé à Supabase,
- [flyai/lib/core/services/ai_service.dart](flyai/lib/core/services/ai_service.dart) : appels IA avec fallback multi-provider.

### 6.2 Modèles

Les modèles métier sont fortement typés et utilisent `Equatable` :

- [flyai/lib/features/profile/models/profile_model.dart](flyai/lib/features/profile/models/profile_model.dart)
- [flyai/lib/features/scholarships/models/scholarship_model.dart](flyai/lib/features/scholarships/models/scholarship_model.dart)

Cette approche facilite la comparaison d’objets et réduit les bugs liés à l’état UI.

---

## 7. Flux métier principaux

### 7.1 Démarrage

1. lancement de `main()`
2. initialisation Firebase + Supabase
3. création du `ProviderScope`
4. chargement du router et du thème
5. redirection vers l’écran adapté selon l’état de connexion

### 7.2 Authentification

1. l’écran appelle un notifier Riverpod,
2. le notifier délègue au service d’authentification,
3. Firebase renvoie un état utilisateur,
4. le router réagit à l’état et redirige vers l’écran approprié.

### 7.3 Découverte de bourses

1. le provider `scholarshipProvider` récupère le profil et les swipes de l’utilisateur,
2. le repository charge les bourses actives depuis Supabase,
3. le matching engine calcule un score de compatibilité,
4. la UI affiche les bourses triées par score.

### 7.4 Assistant IA

1. le notifier de chat récupère la session utilisateur,
2. l’utilisateur envoie un message,
3. le service IA génère une réponse,
4. la réponse est enregistrée et affichée dans la conversation.

---

## 8. Couche ingestion de données

Le dépôt contient aussi un système de collecte de bourses, externe à l’application Flutter :

- [scripts/pipeline.py](scripts/pipeline.py) : orchestration du pipeline,
- [scripts/schema_supabase.sql](scripts/schema_supabase.sql) : schéma de base, tables et index,
- scrapers spécifiques dans [scripts](scripts).

Cette couche permet :

- de collecter des données depuis plusieurs sources,
- de normaliser les bourses,
- de les dédupliquer,
- de les charger dans Supabase.

---

## 9. Forces de l’architecture actuelle

- séparation correcte par feature,
- utilisation cohérente de Riverpod,
- séparation claire entre UI, providers, repositories et services,
- logique de routing centralisée,
- modèles métier bien identifiés,
- architecture adaptée à une première version MVP.

---

## 10. Points d’amélioration prioritaires

### 10.1 Introduire une vraie couche domaine

Aujourd’hui, la logique métier est encore dispersée entre providers, repositories et services. Une couche “use cases” ou “domain” permettrait de mieux isoler la logique métier.

### 10.2 Standardiser les erreurs et les DTOs

Il serait utile d’introduire :

- un mécanisme centralisé de gestion d’erreur,
- des DTOs séparés des modèles UI/domain,
- des exceptions métier explicites.

### 10.3 Abstraire davantage les sources de données

Les repositories sont déjà présents, mais l’accès à Supabase pourrait être encore mieux encapsulé via :

- une couche d’API abstraite,
- un service de cache local,
- une stratégie de fallback offline.

### 10.4 Renforcer la testabilité

Des tests devraient couvrir :

- les providers de matching,
- les repositories,
- les flux d’authentification,
- les règles de navigation.

### 10.5 Clarifier la gouvernance du code

Il serait préférable de définir :

- conventions de nommage,
- structure standard pour les features,
- règles de séparation entre screens, widgets et providers.

---

## 11. Architecture cible recommandée

Pour évoluer vers une base plus robuste, l’architecture peut évoluer vers :

```text
features/
  auth/
  profile/
  scholarships/
  swipe/
  applications/
  ai_assistant/
  dashboard/
    presentation/
    application/
    domain/
    data/
```

Avec :

- `presentation` : screens, widgets, controllers UI,
- `application` : use cases, state, orchestration,
- `domain` : modèles métier, règles, interfaces,
- `data` : repositories, DTOs, services externes.

Cette évolution conserverait les forces actuelles tout en rendant l’application plus scalable et plus facile à maintenir.

---

## 12. Conclusion

L’architecture actuelle de FlyAI est cohérente pour un MVP et respecte déjà plusieurs bonnes pratiques : modularisation par feature, séparation UI/données, état centralisé via Riverpod, et accès aux services via des repositories. Le principal levier d’amélioration consiste à renforcer la couche domaine et à standardiser les flux d’erreurs et la gestion des données pour préparer une montée en complexité durable.
