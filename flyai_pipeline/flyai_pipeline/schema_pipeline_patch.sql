-- =====================================================
-- Fly AI — Schema Patch Pipeline
-- Ajouter les colonnes manquantes pour le pipeline
-- =====================================================

ALTER TABLE scholarships
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS source_url TEXT,
  ADD COLUMN IF NOT EXISTS quality_score INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fingerprint TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Index pour recherche rapide par statut
CREATE INDEX IF NOT EXISTS idx_scholarships_status     ON scholarships(status);
CREATE INDEX IF NOT EXISTS idx_scholarships_fingerprint ON scholarships(fingerprint);
CREATE INDEX IF NOT EXISTS idx_scholarships_deadline    ON scholarships(deadline);
CREATE INDEX IF NOT EXISTS idx_scholarships_active      ON scholarships(active);

-- Contrainte unique sur fingerprint pour upsert idempotent
ALTER TABLE scholarships
  ADD CONSTRAINT IF NOT EXISTS uq_scholarships_fingerprint UNIQUE (fingerprint);

-- Statuts valides
ALTER TABLE scholarships
  ADD CONSTRAINT IF NOT EXISTS chk_scholarships_status
  CHECK (status IN ('upcoming','open','closing_soon','closed','archived','unknown'));
