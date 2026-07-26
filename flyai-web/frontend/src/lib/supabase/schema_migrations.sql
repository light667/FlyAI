-- ═══════════════════════════════════════════════════════════════
-- FlyAI — Schéma Supabase (source de vérité : AUTH FIREBASE)
-- ═══════════════════════════════════════════════════════════════
-- IMPORTANT :
--   • L'auth est FIREBASE (UID = TEXT 28 caractères), pas Supabase Auth.
--   • Toutes les colonnes "utilisateur" s'appellent *_uid / firebase_uid, type TEXT.
--   • Le backend (src/app/api/*) utilise la SUPABASE_SERVICE_ROLE_KEY, qui BYPASS la RLS.
--     → On DISABLE la RLS sur toutes les tables (cohérent avec la sécurité gérée côté API
--        + Firebase). Les anciennes politiques auth.uid() = user_id provoquaient l'erreur
--        "column user_id does not exist" (42703) car les tables live utilisent *_uid.
--
-- APPLI SUR UNE BASE EXISTANTE :
--   `CREATE TABLE IF NOT EXISTS` ne modifie pas une table déjà créée. Si la base contient
--   déjà l'ancien schéma (user_id UUID, author_avatar, read, ...), il faut soit recréer
--   les tables (DROP TABLE ... CASCADE; puis ce script), soit écrire des ALTER ciblés.
--   Pour une base neuve, ce script s'applique tel quel.
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Migration pour ajouter avatar_url si la colonne n'existe pas
ALTER TABLE IF EXISTS public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

-- Migration pour application_documents : changer le bucket et ajouter la colonne folder
ALTER TABLE IF EXISTS public.application_documents ADD COLUMN IF NOT EXISTS folder TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.application_documents ALTER COLUMN bucket SET DEFAULT 'documents';

-- Migration pour ajouter les colonnes manquantes à bourses (si la table existe déjà)
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS financement TEXT DEFAULT 'INCONNU';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS slug TEXT;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'flyai';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS sources TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS sources_ids JSONB DEFAULT '{}'::jsonb;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS deadline_raw TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS date_publication TIMESTAMPTZ;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS annee INTEGER;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS universite TEXT;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS lieu_etude TEXT;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS montant_bourse TEXT;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS nb_bourses INTEGER;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS langues_requises TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS nationalites_eligibles TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS africains_eligibles BOOLEAN DEFAULT FALSE;
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS avantages TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS couverture TEXT[] DEFAULT '{}';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS lien_candidature TEXT DEFAULT '';
ALTER TABLE IF EXISTS public.bourses ADD COLUMN IF NOT EXISTS qualite_score INTEGER DEFAULT 0;

-- Migration critique : renommer scholarship_id en bourse_id dans les tables existantes
-- (pour compatibilité avec le nouveau schéma basé sur 'bourses' au lieu de 'scholarships')
-- On vérifie d'abord si la colonne existe avant de la renommer
DO $$
BEGIN
    -- Pour swipes
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'swipes' AND column_name = 'scholarship_id'
    ) THEN
        EXECUTE 'ALTER TABLE public.swipes RENAME COLUMN scholarship_id TO bourse_id';
    END IF;
    
    -- Pour matches
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'scholarship_id'
    ) THEN
        EXECUTE 'ALTER TABLE public.matches RENAME COLUMN scholarship_id TO bourse_id';
    END IF;
    
    -- Pour applications
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'applications' AND column_name = 'scholarship_id'
    ) THEN
        EXECUTE 'ALTER TABLE public.applications RENAME COLUMN scholarship_id TO bourse_id';
    END IF;
END $$;

-- Migration pour ajouter avatar_url si la colonne n'existe pas
ALTER TABLE IF EXISTS public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

-- Note: La contrainte CHECK sur financement est déjà dans la définition de la table bourses
-- Pas besoin de l'ajouter séparément car elle est incluse dans le CREATE TABLE

-- 1. Profiles (clé = Firebase UID)
CREATE TABLE IF NOT EXISTS public.profiles (
    firebase_uid   TEXT PRIMARY KEY,
    full_name      TEXT DEFAULT '',
    email          TEXT UNIQUE NOT NULL,
    avatar_url     TEXT DEFAULT '',
    nationality    TEXT DEFAULT 'International',
    country        TEXT DEFAULT '',                         -- pays de résidence (signup)
    education_level TEXT DEFAULT 'master',                  -- ex. bachelor / master / phd - NIVEAU ACTUEL
    target_degree_level TEXT DEFAULT NULL,               -- NIVEAU VISE pour le matching (ex: licence, master, doctorat)
    field_of_study TEXT DEFAULT 'Informatique',
    university     TEXT DEFAULT '',
    gpa            NUMERIC(3,2) DEFAULT 3.50,
    english_level  TEXT DEFAULT 'intermediate',
    french_level   TEXT DEFAULT 'intermediate',
    target_countries TEXT[] DEFAULT '{"France", "Allemagne", "Canada"}',
    target_fields  TEXT[] DEFAULT '{}',
    academic_goals TEXT DEFAULT '',
    skills         TEXT[] DEFAULT '{}',
    languages      JSONB DEFAULT '{"english": "B2", "french": "C1"}'::jsonb,
    cv_url         TEXT DEFAULT '',
    bio            TEXT DEFAULT '',
    onboarding_completed BOOLEAN DEFAULT false,
    terms_accepted BOOLEAN DEFAULT false,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Bourses (catalogue — pas d'utilisateur) - SCHEMA COMPATIBLE AVEC DONNEES EXISTANTES
CREATE TABLE IF NOT EXISTS public.bourses (
    id TEXT PRIMARY KEY,
    slug TEXT,
    titre TEXT NOT NULL,
    url TEXT UNIQUE NOT NULL,
    source TEXT DEFAULT 'flyai',
    sources TEXT[] DEFAULT '{}',
    sources_ids JSONB DEFAULT '{}'::jsonb,
    deadline DATE,
    deadline_raw TEXT DEFAULT '',
    date_publication TIMESTAMPTZ,
    annee INTEGER,
    universite TEXT,
    pays_destination TEXT[] DEFAULT '{}',
    lieu_etude TEXT,
    niveau_etude TEXT[] DEFAULT '{}',
    financement TEXT DEFAULT 'INCONNU' CHECK (financement IN ('TOTAL', 'PARTIEL', 'INCONNU')),
    montant_bourse TEXT,
    nb_bourses INTEGER,
    domaines TEXT[] DEFAULT '{}',
    langues_requises TEXT[] DEFAULT '{}',
    nationalites_eligibles TEXT[] DEFAULT '{}',
    africains_eligibles BOOLEAN DEFAULT FALSE,
    description TEXT DEFAULT '',
    avantages TEXT[] DEFAULT '{}',
    criteres TEXT[] DEFAULT '{}',
    couverture TEXT[] DEFAULT '{}',
    lien_candidature TEXT DEFAULT '',
    image_url TEXT DEFAULT '',
    active BOOLEAN DEFAULT TRUE,
    qualite_score INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bourses_deadline ON public.bourses (deadline);
CREATE INDEX IF NOT EXISTS idx_bourses_active ON public.bourses (active);
CREATE INDEX IF NOT EXISTS idx_bourses_financement ON public.bourses (financement);
CREATE INDEX IF NOT EXISTS idx_bourses_niveau ON public.bourses USING gin (niveau_etude);
CREATE INDEX IF NOT EXISTS idx_bourses_pays ON public.bourses USING gin (pays_destination);
CREATE INDEX IF NOT EXISTS idx_bourses_domaines ON public.bourses USING gin (domaines);

-- 3. Swipes (firebase_uid + bourse_id, type TEXT)
CREATE TABLE IF NOT EXISTS public.swipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL,               -- Firebase UID
    bourse_id TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('right', 'left', 'superlike')),
    score INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (firebase_uid, bourse_id)
);
CREATE INDEX IF NOT EXISTS idx_swipes_user ON public.swipes (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_swipes_bourse ON public.swipes (bourse_id);

-- 4. Matches
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL,
    bourse_id TEXT NOT NULL,
    match_score INT DEFAULT 0,
    status TEXT DEFAULT 'new' CHECK (status IN ('new', 'saved', 'applied', 'archived')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (firebase_uid, bourse_id)
);

-- 5. Applications
CREATE TABLE IF NOT EXISTS public.applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL,
    bourse_id TEXT NOT NULL,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'under_review', 'accepted', 'rejected')),
    checklist JSONB DEFAULT '{"cv_uploaded": false, "motivation_letter": false, "transcripts": false, "recommendation_letters": false}'::jsonb,
    notes TEXT DEFAULT '',
    deadline DATE,
    application_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (firebase_uid, bourse_id)
);

-- 5b. Application Documents (for user-uploaded documents)
CREATE TABLE IF NOT EXISTS public.application_documents (
    id TEXT PRIMARY KEY,
    firebase_uid TEXT NOT NULL,
    file_name TEXT NOT NULL,
    stored_name TEXT NOT NULL,
    category TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type TEXT NOT NULL,
    file_extension TEXT DEFAULT '',
    storage_path TEXT NOT NULL,
    bucket TEXT DEFAULT 'documents',
    folder TEXT DEFAULT '',
    download_url TEXT DEFAULT '',
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'uploaded' CHECK (status IN ('uploaded', 'processing', 'error'))
);

CREATE INDEX IF NOT EXISTS idx_application_documents_user ON public.application_documents (firebase_uid);
CREATE INDEX IF NOT EXISTS idx_application_documents_category ON public.application_documents (category);
CREATE INDEX IF NOT EXISTS idx_application_documents_folder ON public.application_documents (folder);
CREATE INDEX IF NOT EXISTS idx_application_documents_uploaded ON public.application_documents (uploaded_at DESC);

-- 6. Chat Sessions & Messages
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT NOT NULL,
    title TEXT DEFAULT 'Nouvelle discussion',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('user', 'assistant')),
    content TEXT NOT NULL,
    context JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Community Posts (schéma live : firebase_uid, author_photo, tags JSONB)
CREATE TABLE IF NOT EXISTS public.posts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid  TEXT NOT NULL,
    author_name   TEXT NOT NULL,
    author_photo  TEXT,
    content       TEXT NOT NULL,
    tags          JSONB DEFAULT '[]'::jsonb,
    likes_count   INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON public.posts (created_at DESC);

CREATE TABLE IF NOT EXISTS public.post_likes (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id      UUID NOT NULL,
    firebase_uid TEXT NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (post_id, firebase_uid)
);

-- 8. Direct Messages (schéma live : sender_uid / receiver_uid / is_read)
CREATE TABLE IF NOT EXISTS public.direct_messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_uid   TEXT NOT NULL,
    receiver_uid TEXT NOT NULL,
    content      TEXT NOT NULL,
    is_read      BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dm_pair ON public.direct_messages (sender_uid, receiver_uid);

-- ═══════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
--   Désactivée partout : la sécurité est gérée côté API (service_role + Firebase).
--   Les anciennes politiques auth.uid() = user_id sont supprimées (elles causaient
--   l'erreur 42703 "column user_id does not exist" sur le schéma live *_uid).
-- ═══════════════════════════════════════════════════════════════
ALTER TABLE public.profiles         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.bourses          DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.swipes           DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches          DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications     DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_documents DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes       DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages  DISABLE ROW LEVEL SECURITY;

-- Realtime publications
-- On utilise un bloc DO avec EXCEPTION pour ignorer les erreurs si la table est déjà dans la publication
-- (compatible avec toutes les versions de PostgreSQL/Supabase)
DO $$
BEGIN
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.posts';
    EXCEPTION WHEN duplicate_object THEN
        -- Table déjà dans la publication, on ignore
        RAISE NOTICE 'Table posts already in supabase_realtime publication';
    END;
    
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Table direct_messages already in supabase_realtime publication';
    END;
    
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.applications';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Table applications already in supabase_realtime publication';
    END;
    
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.swipes';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Table swipes already in supabase_realtime publication';
    END;
    
    BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.bourses';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Table bourses already in supabase_realtime publication';
    END;
END $$;

-- Vue de compatibilité pour le nom 'scholarships' (si utilisé dans le code)
-- D'abord, supprimer la vue scholarships si elle existe (pour éviter le conflit)
DROP VIEW IF EXISTS public.scholarships CASCADE;

-- Puis créer la vue qui pointe vers bourses
CREATE OR REPLACE VIEW public.scholarships AS SELECT * FROM public.bourses;

-- ═══════════════════════════════════════════════════════════════
-- Advanced Matching RPC Function (ne touche qu'à `bourses`)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION match_bourses_advanced(
    p_niveau TEXT,
    p_nationalite TEXT,
    p_pays_cibles TEXT[],
    p_domaines TEXT[],
    p_financement TEXT DEFAULT 'TOTAL',
    p_limit INT DEFAULT 30
)
RETURNS TABLE (
    bourse_id TEXT,
    titre TEXT,
    score INT,
    financement TEXT,
    deadline DATE,
    pays TEXT[],
    domaines TEXT[],
    niveau TEXT[],
    description TEXT,
    url TEXT,
    lien_candidature TEXT,
    image_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id AS bourse_id,
        b.titre,
        (
            -- Niveau etude (30 pts)
            CASE
                WHEN p_niveau = ANY(b.niveau_etude) THEN 30
                WHEN array_length(b.niveau_etude, 1) IS NULL OR array_length(b.niveau_etude, 1) = 0 THEN 15
                ELSE 5
            END
            -- Pays de destination (25 pts)
            + CASE
                WHEN b.pays_destination && p_pays_cibles THEN 25
                WHEN array_length(b.pays_destination, 1) IS NULL OR array_length(b.pays_destination, 1) = 0 THEN 15
                ELSE 5
            END
            -- Domaines d'etude (25 pts)
            + CASE
                WHEN b.domaines && p_domaines THEN 25
                WHEN array_length(b.domaines, 1) IS NULL OR array_length(b.domaines, 1) = 0 THEN 15
                ELSE 5
            END
            -- Type de financement (10 pts)
            + CASE
                WHEN p_financement = 'TOTAL' AND b.financement = 'TOTAL' THEN 10
                WHEN p_financement = 'PARTIEL' AND b.financement IN ('TOTAL', 'PARTIEL') THEN 10
                ELSE 5
            END
            -- Nationalite eligible (10 pts)
            + CASE
                WHEN array_length(b.nationalites_eligibles, 1) IS NULL OR array_length(b.nationalites_eligibles, 1) = 0 THEN 10
                WHEN p_nationalite = ANY(b.nationalites_eligibles) THEN 10
                ELSE 2
            END
        )::INT AS score,
        b.financement,
        b.deadline,
        b.pays_destination AS pays,
        b.domaines,
        b.niveau_etude AS niveau,
        b.description,
        b.url,
        b.lien_candidature,
        b.image_url
    FROM public.bourses b
    WHERE b.active = TRUE
    AND (b.deadline IS NULL OR b.deadline >= CURRENT_DATE)
    ORDER BY score DESC, b.deadline ASC NULLS LAST
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- RPC pour obtenir les documents d'un utilisateur
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_user_documents(p_firebase_uid TEXT)
RETURNS TABLE (
    id TEXT,
    firebase_uid TEXT,
    file_name TEXT,
    stored_name TEXT,
    category TEXT,
    file_size BIGINT,
    mime_type TEXT,
    file_extension TEXT,
    storage_path TEXT,
    bucket TEXT,
    folder TEXT,
    download_url TEXT,
    uploaded_at TIMESTAMPTZ,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        id,
        firebase_uid,
        file_name,
        stored_name,
        category,
        file_size,
        mime_type,
        file_extension,
        storage_path,
        bucket,
        folder,
        download_url,
        uploaded_at,
        status
    FROM public.application_documents
    WHERE firebase_uid = p_firebase_uid
    ORDER BY uploaded_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- RPC pour obtenir la photo de profil d'un utilisateur
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION get_profile_photo(p_firebase_uid TEXT)
RETURNS TABLE (
    id TEXT,
    firebase_uid TEXT,
    file_name TEXT,
    stored_name TEXT,
    download_url TEXT,
    uploaded_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        id,
        firebase_uid,
        file_name,
        stored_name,
        download_url,
        uploaded_at
    FROM public.application_documents
    WHERE firebase_uid = p_firebase_uid
    AND category = 'Photo d''identité'
    ORDER BY uploaded_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════
-- RPC manquant référencé par src/app/api/community/route.ts (like_post)
--   Décrémente atomiquement likes_count d'un post. Sans conflit de concurrence.
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION decrement_post_likes(p_post_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.posts
    SET likes_count = GREATEST(0, COALESCE(likes_count, 0) - 1)
    WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql;
