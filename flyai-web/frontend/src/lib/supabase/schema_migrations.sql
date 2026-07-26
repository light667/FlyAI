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

-- 1. Profiles (clé = Firebase UID)
CREATE TABLE IF NOT EXISTS public.profiles (
    firebase_uid   TEXT PRIMARY KEY,
    full_name      TEXT DEFAULT '',
    email          TEXT UNIQUE NOT NULL,
    avatar_url     TEXT DEFAULT '',
    nationality    TEXT DEFAULT 'International',
    country        TEXT DEFAULT '',                         -- pays de résidence (signup)
    education_level TEXT DEFAULT 'master',                  -- ex. bachelor / master / phd
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
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Bourses (catalogue — pas d'utilisateur)
CREATE TABLE IF NOT EXISTS public.bourses (
    id TEXT PRIMARY KEY,
    titre TEXT NOT NULL,
    url TEXT UNIQUE NOT NULL,
    deadline DATE,
    deadline_raw TEXT DEFAULT '',
    pays_destination TEXT[] DEFAULT '{}',
    niveau_etude TEXT[] DEFAULT '{}',
    financement TEXT DEFAULT 'INCONNU' CHECK (financement IN ('TOTAL', 'PARTIEL', 'INCONNU')),
    domaines TEXT[] DEFAULT '{}',
    langues_requises TEXT[] DEFAULT '{}',
    nationalites_eligibles TEXT[] DEFAULT '{}',
    description TEXT DEFAULT '',
    avantages TEXT[] DEFAULT '{}',
    criteres TEXT[] DEFAULT '{}',
    lien_candidature TEXT DEFAULT '',
    image_url TEXT DEFAULT '',
    date_publication TIMESTAMPTZ,
    source TEXT DEFAULT 'flyai',
    active BOOLEAN DEFAULT TRUE,
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
ALTER TABLE public.chat_sessions    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages    DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes       DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages  DISABLE ROW LEVEL SECURITY;

-- Realtime publications
ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.applications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.swipes;

-- ═══════════════════════════════════════════════════════════════
-- Advanced Matching RPC Function (inchangée — ne touche qu'à `bourses`)
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
