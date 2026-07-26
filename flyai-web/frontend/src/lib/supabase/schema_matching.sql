-- ═══════════════════════════════════════════════════════════════
-- FlyAI — Tables Sprint 2 : matching_scores + matching_feedback
-- Supabase SQL Editor : Settings → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- 1. Score de compatibilité calculé pour chaque paire user/bourse
CREATE TABLE IF NOT EXISTS matching_scores (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           TEXT NOT NULL,         -- Firebase UID
  scholarship_id    TEXT NOT NULL,
  overall_score     INTEGER NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  degree_score      INTEGER DEFAULT 0,
  domain_score      INTEGER DEFAULT 0,
  country_score     INTEGER DEFAULT 0,
  language_score    INTEGER DEFAULT 0,
  funding_score     INTEGER DEFAULT 0,
  semantic_score    INTEGER DEFAULT 0,
  breakdown         JSONB,                 -- [{criterion, score, max, detail, is_hard_filter}]
  computed_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matching_scores_user ON matching_scores (user_id);
CREATE INDEX IF NOT EXISTS idx_matching_scores_score ON matching_scores (user_id, overall_score DESC);

-- 2. Feedback utilisateur sur la pertinence du score (§10.2 boucle d'amélioration)
CREATE TABLE IF NOT EXISTS matching_feedback (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           TEXT NOT NULL,
  scholarship_id    TEXT NOT NULL,
  score_id          UUID REFERENCES matching_scores(id) ON DELETE SET NULL,
  feedback          TEXT NOT NULL CHECK (feedback IN ('up', 'down')),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matching_feedback_user ON matching_feedback (user_id);

-- 3. RLS (Row Level Security) — lecture/écriture restreintes à l'utilisateur propriétaire
ALTER TABLE matching_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE matching_feedback ENABLE ROW LEVEL SECURITY;

-- Politique : chaque utilisateur ne voit que ses propres scores
-- (Adapter selon votre setup d'authentification Firebase/Supabase)
-- Si vous utilisez Supabase Auth natif :
-- CREATE POLICY "own_scores" ON matching_scores FOR ALL USING (auth.uid()::text = user_id);
-- CREATE POLICY "own_feedback" ON matching_feedback FOR ALL USING (auth.uid()::text = user_id);

-- Si Firebase JWT (recommandé pour ce projet) — laisser RLS géré côté API (service_role)
-- et ne pas activer de politique restrictive ici pour ne pas bloquer le backend.

-- 4. Vue agrégée pour le tableau de bord analytics (§14)
--    - Toutes les colonnes du SELECT sont qualifiées (ms./fb.) pour lever
--      l'ambiguïté 42702 : matching_scores ET matching_feedback ont scholarship_id.
--    - Les feedbacks sont pré-agrégés par score_id dans une sous-requête,
--      sinon le LEFT JOIN duplique chaque score (COUNT(*) et AVG faussés).
CREATE OR REPLACE VIEW matching_analytics AS
SELECT
  ms.scholarship_id,
  COUNT(DISTINCT ms.id)                                  AS total_scores,
  ROUND(AVG(ms.overall_score), 1)                        AS avg_score,
  COUNT(DISTINCT ms.id) FILTER (WHERE ms.overall_score >= 75) AS high_matches,
  COALESCE(fb.thumbs_up, 0)                              AS thumbs_up,
  COALESCE(fb.thumbs_down, 0)                            AS thumbs_down
FROM matching_scores ms
LEFT JOIN (
  SELECT
    score_id,
    COUNT(*) FILTER (WHERE feedback = 'up')   AS thumbs_up,
    COUNT(*) FILTER (WHERE feedback = 'down') AS thumbs_down
  FROM matching_feedback
  GROUP BY score_id
) fb ON fb.score_id = ms.id
GROUP BY ms.scholarship_id
ORDER BY high_matches DESC;
