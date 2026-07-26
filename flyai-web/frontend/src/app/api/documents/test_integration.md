# Test d'Intégration - Système de Documents

## Prérequis

1. Le bucket Supabase **`documents`** existe avec les dossiers :
   - `documents/cvs/`
   - `documents/photos/`

2. La table **`application_documents`** a été migrée avec la nouvelle colonne `folder` et le bucket par défaut `documents`

3. La table **`profiles`** existe avec la colonne `avatar_url`

## Tests à Effectuer

### 1. Upload d'un CV
**Endpoint**: `POST /api/documents`

```javascript
const formData = new FormData();
formData.append("userId", "test_user_123");
formData.append("category", "CV");
formData.append("file", file); // PDF file

fetch("/api/documents", {
  method: "POST",
  body: formData
});
```

**Résultat attendu**:
- Fichier stocké dans : `documents/cvs/test_user_123/{timestamp}_test_user_123_CV.pdf`
- Enregistrement en base de données avec :
  - `bucket`: "documents"
  - `folder`: "cvs"
  - `category`: "CV"
  - `firebase_uid`: "test_user_123"
- **Pas de mise à jour** de `profiles.avatar_url`

### 2. Upload d'une Photo d'Identité
**Endpoint**: `POST /api/documents`

```javascript
const formData = new FormData();
formData.append("userId", "test_user_123");
formData.append("category", "Photo d'identité");
formData.append("file", file); // JPEG/PNG file

fetch("/api/documents", {
  method: "POST",
  body: formData
});
```

**Résultat attendu**:
- Fichier stocké dans : `documents/photos/test_user_123/{timestamp}_test_user_123_Photo_didentite.jpg`
- Enregistrement en base de données avec :
  - `bucket`: "documents"
  - `folder`: "photos"
  - `category`: "Photo d'identité"
  - `firebase_uid`: "test_user_123"
- **Mise à jour automatique** de `profiles.avatar_url` avec le signed URL du fichier

### 3. Récupération des Documents
**Endpoint**: `GET /api/documents?userId=test_user_123`

**Résultat attendu**:
```json
{
  "success": true,
  "data": [
    {
      "id": "photos/test_user_123/...",
      "firebase_uid": "test_user_123",
      "file_name": "ma_photo.jpg",
      "category": "Photo d'identité",
      "folder": "photos",
      "bucket": "documents",
      "download_url": "https://...",
      "status": "uploaded"
    },
    {
      "id": "cvs/test_user_123/...",
      "firebase_uid": "test_user_123",
      "file_name": "mon_cv.pdf",
      "category": "CV",
      "folder": "cvs",
      "bucket": "documents",
      "download_url": "https://...",
      "status": "uploaded"
    }
  ]
}
```

### 4. Suppression d'un Document (non photo)
**Endpoint**: `DELETE /api/documents?userId=test_user_123&documentId={documentId}`

**Résultat attendu**:
- Fichier supprimé du stockage
- Enregistrement supprimé de la base de données
- **Pas de modification** de `profiles.avatar_url`

### 5. Suppression d'une Photo d'Identité
**Endpoint**: `DELETE /api/documents?userId=test_user_123&documentId={photoDocumentId}`

**Résultat attendu**:
- Fichier supprimé du stockage
- Enregistrement supprimé de la base de données
- **Réinitialisation** de `profiles.avatar_url` à une chaîne vide

## Vérifications Supabase

### 1. Vérifier le bucket
```sql
SELECT * FROM storage.buckets WHERE name = 'documents';
```

### 2. Vérifier les dossiers
Dans l'interface Supabase Storage, vérifier que :
- `documents/cvs/{userId}/` existe avec les fichiers
- `documents/photos/{userId}/` existe avec les photos

### 3. Vérifier la table application_documents
```sql
SELECT * FROM public.application_documents WHERE firebase_uid = 'test_user_123';
```

### 4. Vérifier le profil utilisateur
```sql
SELECT avatar_url FROM public.profiles WHERE firebase_uid = 'test_user_123';
```

## Tests Frontend (DocumentsTab)

### 1. Affichage des documents
- Ouvrir la page avec `DocumentsTab`
- Vérifier que tous les documents sont affichés
- Vérifier que la photo d'identité active a le badge "Photo de profil active"

### 2. Upload via l'interface
- Cliquer sur "Ajouter un document"
- Sélectionner une catégorie et un fichier
- Vérifier que le document apparaît dans la liste
- Si c'est une photo d'identité, vérifier qu'elle est marquée comme active

### 3. Suppression via l'interface
- Cliquer sur l'icône de suppression d'un document
- Vérifier qu'il disparaît de la liste
- Si c'était une photo d'identité active, vérifier que le badge disparaît

## Dépannage

### Erreur : "bucket does not exist"
**Solution**: Créer le bucket `documents` dans Supabase Storage avec les permissions appropriées.

### Erreur : "column folder does not exist"
**Solution**: Exécuter la migration pour ajouter la colonne :
```sql
ALTER TABLE public.application_documents ADD COLUMN IF NOT EXISTS folder TEXT DEFAULT '';
```

### Erreur : "relation application_documents does not exist"
**Solution**: Exécuter le script complet `schema_migrations.sql`

### Les photos ne mettent pas à jour avatar_url
**Solution**: Vérifier que :
1. La catégorie est exactement "Photo d'identité" (respecter la casse et les accents)
2. Le signed URL est bien généré (vérifier les permissions du bucket)
3. La table profiles existe et a la colonne avatar_url

### Les fichiers ne sont pas dans le bon dossier
**Solution**: Vérifier la logique dans `route.ts` :
```typescript
const folder = category === "Photo d'identité" ? "photos" : "cvs";
```
