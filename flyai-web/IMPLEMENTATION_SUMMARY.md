# Résumé de l'Implémentation - Système de Documents FlyAI

## Objectif

Implémenter un système complet de gestion de documents pour l'application FlyAI, utilisant le bucket Supabase Storage existant **`documents`** avec les sous-dossiers `cvs/` et `photos/`, où chaque donnée est liée à un utilisateur Firebase.

## Structure du Bucket

```
documents/
├── cvs/
│   └── {userId}/
│       ├── {timestamp}_{userId}_CV.pdf
│       ├── {timestamp}_{userId}_Relevé_de_notes.pdf
│       ├── {timestamp}_{userId}_Diplôme.pdf
│       ├── ...
│
└── photos/
    └── {userId}/
        └── {timestamp}_{userId}_Photo_d'identité.jpg
```

## Fichiers Modifiés

### 1. `frontend/src/lib/supabase/schema_migrations.sql`

**Modifications :**

1. **Migration pour `application_documents`** (lignes 24-26) :
   - Ajout de la colonne `folder` : `ALTER TABLE IF EXISTS public.application_documents ADD COLUMN IF NOT EXISTS folder TEXT DEFAULT '';`
   - Changement du bucket par défaut : `ALTER TABLE IF EXISTS public.application_documents ALTER COLUMN bucket SET DEFAULT 'documents';`

2. **Table `application_documents`** (lignes 168-184) :
   - Changement du bucket par défaut de `'user-documents'` à `'documents'`
   - Ajout de la colonne `folder TEXT DEFAULT ''`

3. **Index** (lignes 186-189) :
   - Ajout de l'index `idx_application_documents_folder` sur la colonne `folder`

4. **Fonctions RPC** (lignes 353-403) :
   - Ajout de `get_user_documents(p_firebase_uid TEXT)` : Retourne tous les documents d'un utilisateur
   - Ajout de `get_profile_photo(p_firebase_uid TEXT)` : Retourne la photo de profil la plus récente

### 2. `frontend/src/app/api/documents/route.ts`

**Modifications :**

1. **Upload de fichier** (lignes 81-94) :
   - Changement du bucket de `"user-documents"` à `"documents"`
   - Détermination du dossier basé sur la catégorie :
     ```typescript
     const folder = category === "Photo d'identité" ? "photos" : "cvs";
     const storagePath = `${folder}/${userId}/${fileName}`;
     ```
   - Suppression de la création automatique du bucket (puisqu'il existe déjà)

2. **Génération de l'URL signée** (lignes 104-107) :
   - Utilisation du bon `storagePath` au lieu de `users/${userId}/${fileName}`

3. **Mise à jour automatique de l'avatar** (lignes 113-123) :
   - Si `category === "Photo d'identité"`, mise à jour de `profiles.avatar_url` avec le signed URL
   ```typescript
   if (category === "Photo d'identité" && urlData?.signedUrl) {
     const { error: updateAvatarError } = await supabase
       .from("profiles")
       .update({ avatar_url: urlData.signedUrl })
       .eq("firebase_uid", userId);
   }
   ```

4. **Sauvegarde des métadonnées** (lignes 125-141) :
   - Ajout de la propriété `folder` dans `documentData`

5. **Suppression de document** (lignes 256-266) :
   - Si le document est une photo d'identité, réinitialisation de `profiles.avatar_url` à `""`

### 3. `frontend/src/components/dashboard/DocumentsTab.tsx`

**Modifications :**

1. **Interface `DocumentItem`** (lignes 27-39) :
   - Ajout de la propriété optionnelle `folder?: string`

2. **Fonction utilitaire** (lignes 87-89) :
   - Ajout de `isProfilePhoto(category: string): boolean` pour identifier les photos de profil

3. **Affichage des documents** (lignes 394-401) :
   - Ajout d'un badge "Photo de profil active" pour les photos d'identité qui correspondent à l'avatar actuel
   ```typescript
   {isProfilePhoto(doc.category) && userProfile?.avatar_url === doc.download_url && (
     <span className="ml-2 text-pink-500 font-bold">• Photo de profil active</span>
   )}
   ```

### 4. Nouveaux Fichiers

1. **`frontend/src/lib/supabase/storage_config.md`** : Documentation complète de la configuration du stockage
2. **`frontend/src/app/api/documents/test_integration.md`** : Guide de test d'intégration

## Fonctionnalités Implémentées

### ✅ Upload de Documents
- **Catégorisation automatique** : Les documents sont classés dans `cvs/` ou `photos/` selon leur catégorie
- **Nommage unique** : `{timestamp}_{userId}_{category}.{ext}`
- **Gestion des photos de profil** : Mise à jour automatique de `profiles.avatar_url`
- **Validation** : Taille max (10 Mo), types MIME autorisés (PDF, JPEG, PNG, WebP, Word)

### ✅ Récupération des Documents
- Liste complète des documents d'un utilisateur
- Tri par date de téléversement (plus récent en premier)
- Filtre par utilisateur via `firebase_uid`

### ✅ Suppression des Documents
- Suppression du fichier du stockage
- Suppression de l'enregistrement de la base de données
- **Gestion spéciale pour les photos** : Réinitialisation de `avatar_url` si suppression d'une photo de profil

### ✅ Affichage Frontend
- Interface intuitive avec modal d'upload
- Affichage des catégories avec icônes et couleurs
- Indication visuelle de la photo de profil active
- Actions : télécharger, supprimer

## Sécurité

- ✅ **Bucket privé** : `documents` est non public
- ✅ **URL signées** : Générées avec `createSignedUrl` (validité : 1 an)
- ✅ **RLS désactivée** : Sécurité gérée côté API avec `SUPABASE_SERVICE_ROLE_KEY`
- ✅ **Lien utilisateur** : Chaque document est associé à un `firebase_uid`

## Catégories Supportées

| Catégorie | Dossier | Mise à jour Avatar |
|----------|--------|-------------------|
| CV | cvs/ | ❌ |
| Relevé de notes | cvs/ | ❌ |
| Diplôme | cvs/ | ❌ |
| Certificat de Langue | cvs/ | ❌ |
| Lettre de motivation | cvs/ | ❌ |
| Lettre de recommandation | cvs/ | ❌ |
| Passeport | cvs/ | ❌ |
| **Photo d'identité** | **photos/** | **✅** |
| Autre | cvs/ | ❌ |

## Points d'API

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/documents` | Upload un document |
| GET | `/api/documents?userId={userId}` | Récupérer les documents d'un utilisateur |
| DELETE | `/api/documents?userId={userId}&documentId={documentId}` | Supprimer un document |

## Migration de la Base de Données

Pour appliquer les changements sur une base existante :

```sql
-- 1. Ajouter la colonne folder
ALTER TABLE IF EXISTS public.application_documents ADD COLUMN IF NOT EXISTS folder TEXT DEFAULT '';

-- 2. Changer le bucket par défaut
ALTER TABLE IF EXISTS public.application_documents ALTER COLUMN bucket SET DEFAULT 'documents';

-- 3. Créer l'index sur folder
CREATE INDEX IF NOT EXISTS idx_application_documents_folder ON public.application_documents (folder);

-- 4. Exécuter le CREATE TABLE IF NOT EXISTS pour s'assurer que tout est à jour
-- (déjà inclus dans schema_migrations.sql)
```

## Tests Recommandés

1. **Upload d'un CV** → Vérifier qu'il va dans `documents/cvs/{userId}/`
2. **Upload d'une photo** → Vérifier qu'elle va dans `documents/photos/{userId}/` et que `avatar_url` est mis à jour
3. **Suppression d'une photo** → Vérifier que `avatar_url` est réinitialisé
4. **Affichage** → Vérifier que la photo active a le badge

## Prochaines Étapes

- [ ] Exécuter le script `schema_migrations.sql` sur la base Supabase
- [ ] Tester l'upload via Postman ou l'interface frontend
- [ ] Vérifier que le bucket `documents` existe dans Supabase Storage
- [ ] Vérifier que les dossiers `cvs/` et `photos/` sont créés automatiquement

## Résolution des Problèmes

### Problème : "bucket does not exist"
**Solution** : Créer le bucket `documents` dans Supabase Storage (Interface → Storage → Create Bucket)

### Problème : "column folder does not exist"
**Solution** : Exécuter la migration : `ALTER TABLE public.application_documents ADD COLUMN folder TEXT DEFAULT '';`

### Problème : Les photos ne mettent pas à jour avatar_url
**Solution** : Vérifier :
1. La catégorie est exactement "Photo d'identité" (respecter la casse et les accents)
2. Le bucket `documents` existe et est accessible
3. La table `profiles` existe avec la colonne `avatar_url`
4. Le service role a les permissions nécessaires

### Problème : Les fichiers ne sont pas dans le bon dossier
**Solution** : Vérifier la logique dans `route.ts` ligne 85 :
```typescript
const folder = category === "Photo d'identité" ? "photos" : "cvs";
```

## Historique des Versions

| Date | Version | Modifications |
|------|---------|---------------|
| 2026-07-26 | 1.0 | Implémentation complète du système de documents |

---

**Auteur** : Implémentation par Mistral Vibe  
**Date** : 26 Juillet 2026  
**Statut** : ✅ Complété
