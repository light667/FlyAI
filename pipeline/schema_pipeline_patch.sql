-- =====================================================
-- Fly AI — Schema Patch Pipeline
-- Coller dans Supabase SQL Editor et exécuter
-- =====================================================

-- 1. Colonnes manquantes
ALTER TABLE scholarships
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS source_url TEXT,
  ADD COLUMN IF NOT EXISTS quality_score INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fingerprint TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 2. Contrainte UNIQUE sur fingerprint (syntaxe compatible PostgreSQL)
--    IF NOT EXISTS n'est pas supporté pour ADD CONSTRAINT → on utilise un bloc DO
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_scholarships_fingerprint'
      AND conrelid = 'scholarships'::regclass
  ) THEN
    ALTER TABLE scholarships
      ADD CONSTRAINT uq_scholarships_fingerprint UNIQUE (fingerprint);
  END IF;
END $$;

-- 3. Contrainte CHECK sur status (même approche)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_scholarships_status'
      AND conrelid = 'scholarships'::regclass
  ) THEN
    ALTER TABLE scholarships
      ADD CONSTRAINT chk_scholarships_status
      CHECK (status IN ('upcoming','open','closing_soon','closed','archived','unknown'));
  END IF;
END $$;

-- 4. Index pour performances
CREATE INDEX IF NOT EXISTS idx_scholarships_status      ON scholarships(status);
CREATE INDEX IF NOT EXISTS idx_scholarships_fingerprint ON scholarships(fingerprint);
CREATE INDEX IF NOT EXISTS idx_scholarships_deadline    ON scholarships(deadline);
CREATE INDEX IF NOT EXISTS idx_scholarships_active      ON scholarships(active);
