# Configuration du Stockage Supabase - FlyAI

## Structure du Bucket

Le système utilise le bucket existant **`documents`** avec la structure de dossiers suivante :

```
documents/
├── cvs/
│   └── {userId}/
│       ├── {timestamp}_{userId}_CV.pdf
│       ├── {timestamp}_{userId}_Relevé_de_notes.pdf
│       └── ... (tous les documents sauf photos de profil)
│
└── photos/
    └── {userId}/
        └── {timestamp}_{userId}_Photo_d'identité.jpg
```

## Catégories de Documents

Les catégories supportées sont :

1. **CV** → Stocké dans `documents/cvs/{userId}/`
2. **Relevé de notes** → Stocké dans `documents/cvs/{userId}/`
3. **Diplôme** → Stocké dans `documents/cvs/{userId}/`
4. **Certificat de Langue** → Stocké dans `documents/cvs/{userId}/`
5. **Lettre de motivation** → Stocké dans `documents/cvs/{userId}/`
6. **Lettre de recommandation** → Stocké dans `documents/cvs/{userId}/`
7. **Passeport** → Stocké dans `documents/cvs/{userId}/`
8. **Photo d'identité** → Stocké dans `documents/photos/{userId}/` **ET met à jour `profiles.avatar_url`**
9. **Autre** → Stocké dans `documents/cvs/{userId}/`

## Schéma de la Base de Données

### Table : `application_documents`

| Colonne | Type | Description | Default |
|--------|------|-------------|---------|
| id | TEXT | PK, chemin du fichier dans storage | - |
| firebase_uid | TEXT | NOT NULL, lien à l'utilisateur | - |
| file_name | TEXT | NOT NULL, nom original du fichier | - |
| stored_name | TEXT | NOT NULL, nom stocké (avec timestamp) | - |
| category | TEXT | NOT NULL, catégorie du document | - |
| file_size | BIGINT | NOT NULL, taille en bytes | - |
| mime_type | TEXT | NOT NULL, type MIME | - |
| file_extension | TEXT | Extension du fichier | '' |
| storage_path | TEXT | NOT NULL, chemin complet dans le bucket | - |
| bucket | TEXT | Nom du bucket | 'documents' |
| folder | TEXT | Sous-dossier (cvs ou photos) | '' |
| download_url | TEXT | URL signée pour téléchargement | '' |
| uploaded_at | TIMESTAMPTZ | Date de téléversement | NOW() |
| status | TEXT | Statut (uploaded, processing, error) | 'uploaded' |

### Index
- `idx_application_documents_user` : Sur `firebase_uid`
- `idx_application_documents_category` : Sur `category`
- `idx_application_documents_folder` : Sur `folder`
- `idx_application_documents_uploaded` : Sur `uploaded_at DESC`

## Fonctions RPC

### `get_user_documents(p_firebase_uid TEXT)`
Retourne tous les documents d'un utilisateur, triés par date de téléversement décroissante.

### `get_profile_photo(p_firebase_uid TEXT)`
Retourne la photo de profil la plus récente d'un utilisateur (catégorie = 'Photo d'identité').

## Logique Métier

### Upload de Document
1. Détermine le dossier en fonction de la catégorie :
   - Si `category === "Photo d'identité"` → dossier = `photos`
   - Sinon → dossier = `cvs`

2. Génère le chemin de stockage : `{folder}/{userId}/{timestamp}_{userId}_{category}.{ext}`

3. Upload le fichier vers `documents/{storagePath}`

4. **Si c'est une photo d'identité** :
   - Met à jour `profiles.avatar_url` avec le signed URL du fichier
   - Cette URL est valable 1 an

5. Sauvegarde les métadonnées dans `application_documents`

### Suppression de Document
1. Si le document est une photo d'identité :
   - Réinitialise `profiles.avatar_url` à une chaîne vide

2. Supprime le fichier du stockage

3. Supprime l'enregistrement de la base de données

## Sécurité

- Le bucket `documents` est **privé** (non public)
- Les URL sont générées avec `createSignedUrl` (validité : 1 an)
- Toutes les tables ont la **Row Level Security désactivée** (sécurité gérée côté API avec SUPABASE_SERVICE_ROLE_KEY)
- Chaque document est lié à un `firebase_uid`

## API Endpoints

### POST `/api/documents`
Upload un document.

**Paramètres (FormData)** :
- `userId` (string) : Firebase UID de l'utilisateur
- `category` (string) : Une des catégories listées ci-dessus
- `file` (File) : Le fichier à uploader

**Réponse** :
```json
{
  "success": true,
  "message": "Document uploaded successfully",
  "data": {
    "id": "...",
    "fileName": "...",
    "category": "...",
    "size": 12345,
    "url": "https://...",
    "storagePath": "photos/{userId}/...",
    "uploadedAt": "2024-..."
  }
}
```

### GET `/api/documents?userId={userId}`
Récupère tous les documents d'un utilisateur.

### DELETE `/api/documents?userId={userId}&documentId={documentId}`
Supprime un document.

## Intégration Frontend

Le composant `DocumentsTab.tsx` gère :
- L'upload de documents via un modal
- L'affichage de la liste des documents
- La suppression de documents
- L'indication visuelle que la photo d'identité est utilisée comme avatar

## Notes

- Taille maximale des fichiers : 10 Mo
- Types MIME autorisés : PDF, JPEG, PNG, WebP, Word documents
- Le nom des fichiers stockés inclut un timestamp pour éviter les conflits
- Les photos de profil sont automatiquement liées au champ `avatar_url` du profil utilisateur
