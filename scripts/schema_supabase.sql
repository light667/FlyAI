-- FlyAI — Schéma Supabase pour la table bourses
-- Coller dans l'éditeur SQL de Supabase et exécuter

-- Extension pour UUID (déjà activée par défaut sur Supabase)
create extension if not exists "uuid-ossp";

-- ─── Table principale des bourses ─────────────────────────────────────────────
create table if not exists bourses (
    id              text primary key,           -- SHA1(url)[:12]
    titre           text not null,
    url             text unique not null,
    deadline        date,                        -- NULL si non trouvée
    deadline_raw    text default '',
    pays_destination text[] default '{}',        -- ["France", "Germany"]
    niveau_etude    text[] default '{}',         -- ["master", "doctorat"]
    financement     text default 'INCONNU'
                    check (financement in ('TOTAL', 'PARTIEL', 'INCONNU')),
    domaines        text[] default '{}',
    langues_requises text[] default '{}',
    nationalites_eligibles text[] default '{}',
    description     text default '',
    avantages       text[] default '{}',
    criteres        text[] default '{}',
    lien_candidature text default '',
    image_url       text default '',
    date_publication timestamptz,
    source          text default 'opportunitiesforafricans.com',
    active          boolean default true,
    created_at      timestamptz default now(),
    updated_at      timestamptz default now()
);

-- ─── Index pour les requêtes de matching ──────────────────────────────────────
create index if not exists idx_bourses_deadline        on bourses (deadline);
create index if not exists idx_bourses_active          on bourses (active);
create index if not exists idx_bourses_financement     on bourses (financement);
create index if not exists idx_bourses_niveau          on bourses using gin (niveau_etude);
create index if not exists idx_bourses_pays            on bourses using gin (pays_destination);
create index if not exists idx_bourses_domaines        on bourses using gin (domaines);
create index if not exists idx_bourses_nationalites    on bourses using gin (nationalites_eligibles);

-- ─── Trigger : met à jour updated_at automatiquement ─────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger bourses_updated_at
    before update on bourses
    for each row execute function update_updated_at();

-- ─── Vue : bourses actives seulement ──────────────────────────────────────────
create or replace view bourses_actives as
    select * from bourses
    where active = true
    and (deadline is null or deadline >= current_date)
    order by deadline asc nulls last;

-- ─── Fonction de matching FlyAI ───────────────────────────────────────────────
-- Retourne les bourses compatibles avec un profil étudiant
-- avec un score de compatibilité 0-100
create or replace function match_bourses(
    p_niveau        text,           -- ex: 'master'
    p_nationalite   text,           -- ex: 'Togolais'
    p_pays_cibles   text[],         -- ex: ['France', 'Allemagne']
    p_domaines      text[],         -- ex: ['informatique', 'génie']
    p_financement   text default 'TOTAL',  -- TOTAL | PARTIEL | INCONNU (tous)
    p_limit         int default 20
)
returns table (
    bourse_id   text,
    titre       text,
    score       int,
    financement text,
    deadline    date,
    pays        text[]
) as $$
begin
    return query
    select
        b.id,
        b.titre,
        (
            -- Score niveau (35 pts)
            case when p_niveau = any(b.niveau_etude) then 35 else 0 end
            -- Score pays (25 pts)
            + case when b.pays_destination && p_pays_cibles then 25 else 0 end
            -- Score domaines (20 pts)
            + case when b.domaines && p_domaines then 20 else 0 end
            -- Score financement (15 pts)
            + case
                when p_financement = 'TOTAL' and b.financement = 'TOTAL' then 15
                when p_financement = 'PARTIEL' and b.financement in ('TOTAL', 'PARTIEL') then 15
                else 5
              end
            -- Score nationalité (5 pts)
            + case
                when array_length(b.nationalites_eligibles, 1) = 0 then 5  -- ouvert à tous
                when p_nationalite = any(b.nationalites_eligibles) then 5
                else 0
              end
        )::int as score,
        b.financement,
        b.deadline,
        b.pays_destination
    from bourses b
    where b.active = true
    and (b.deadline is null or b.deadline >= current_date)
    order by score desc, b.deadline asc nulls last
    limit p_limit;
end;
$$ language plpgsql;

-- ─── Table swipes utilisateur ─────────────────────────────────────────────────
create table if not exists swipes (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    bourse_id   text not null references bourses(id) on delete cascade,
    direction   text not null check (direction in ('right', 'left')),  -- right=like, left=skip
    created_at  timestamptz default now(),
    unique (user_id, bourse_id)
);

create index if not exists idx_swipes_user    on swipes (user_id);
create index if not exists idx_swipes_bourse  on swipes (bourse_id);

-- ─── RLS (Row Level Security) ─────────────────────────────────────────────────
-- Les utilisateurs ne voient que leurs propres swipes
alter table swipes enable row level security;

create policy "user_swipes_own" on swipes
    for all using (auth.uid() = user_id);

-- Les bourses sont publiques en lecture
alter table bourses enable row level security;

create policy "bourses_public_read" on bourses
    for select using (true);

-- ─── Données de test ──────────────────────────────────────────────────────────
insert into bourses (id, titre, url, deadline, financement, niveau_etude, pays_destination, description, active)
values (
    'test_001',
    'Bourse Erasmus Mundus EMJMD 2026 — Entièrement Financée',
    'https://example.com/erasmus-2026',
    '2026-12-31',
    'TOTAL',
    array['master'],
    array['France', 'Allemagne', 'Espagne', 'Italie'],
    'Le programme Erasmus Mundus est un programme de bourses de l''Union Européenne ouvert aux étudiants du monde entier.',
    true
) on conflict (id) do nothing;
