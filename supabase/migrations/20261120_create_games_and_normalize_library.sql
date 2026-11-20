-- Migração Supabase: Separação de Catálogo Compartilhado (games) e Biblioteca Pessoal (library_entries)
-- Arquivo: supabase/migrations/20261120_create_games_and_normalize_library.sql

-- 1. Criação da tabela de catálogo de jogos compartilhado
CREATE TABLE IF NOT EXISTS public.games (
    id INTEGER PRIMARY KEY, -- ID oficial da IGDB
    name TEXT NOT NULL,
    cover_url TEXT,
    summary TEXT,
    storyline TEXT,
    rating NUMERIC,
    release_year TEXT,
    genres JSONB DEFAULT '[]'::jsonb,
    platforms JSONB DEFAULT '[]'::jsonb,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Índices para consultas no catálogo de jogos
CREATE INDEX IF NOT EXISTS idx_games_name ON public.games(name);
CREATE INDEX IF NOT EXISTS idx_games_rating ON public.games(rating DESC);
CREATE INDEX IF NOT EXISTS idx_games_updated_at ON public.games(updated_at DESC);

-- Trigger para atualizar automaticamente o updated_at da tabela games
DROP TRIGGER IF EXISTS trigger_games_updated_at ON public.games;
CREATE TRIGGER trigger_games_updated_at
    BEFORE UPDATE ON public.games
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 2. Migrar dados já existentes de library_entries para a nova tabela games
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'library_entries'
    ) THEN
        INSERT INTO public.games (id, name, cover_url, summary, rating, release_year, raw_data)
        SELECT DISTINCT
            le.game_id,
            le.game_name,
            le.game_data->>'cover_url',
            le.game_data->>'summary',
            CASE 
                WHEN le.game_data->>'rating' ~ '^[0-9]+(\.[0-9]+)?$' THEN (le.game_data->>'rating')::numeric
                ELSE NULL
            END,
            le.game_data->>'release_year',
            COALESCE(le.game_data, '{}'::jsonb)
        FROM public.library_entries le
        WHERE le.game_id IS NOT NULL AND le.game_name IS NOT NULL
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            raw_data = EXCLUDED.raw_data,
            updated_at = now();
    END IF;
END $$;

-- 3. Remover completamente as colunas redundantes de library_entries
-- Eliminando dados desnormalizados de usuário (já em auth.users) e de jogo (já em public.games)
ALTER TABLE public.library_entries
    DROP COLUMN IF EXISTS user_name,
    DROP COLUMN IF EXISTS user_email,
    DROP COLUMN IF EXISTS game_name,
    DROP COLUMN IF EXISTS game_data;

-- Adicionar Foreign Key referenciando a tabela games
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_library_entries_game'
        AND table_name = 'library_entries'
    ) THEN
        ALTER TABLE public.library_entries
            ADD CONSTRAINT fk_library_entries_game
            FOREIGN KEY (game_id) REFERENCES public.games(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 4. Políticas de Segurança (Row Level Security) para public.games
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;

-- Leitura do catálogo: permitida para usuários autenticados e anônimos
DROP POLICY IF EXISTS "Leitura de jogos permitida para todos autenticados" ON public.games;
DROP POLICY IF EXISTS "Leitura de jogos permitida para todos" ON public.games;
CREATE POLICY "Leitura de jogos permitida para todos"
    ON public.games
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Inserção no catálogo: permitida para usuários autenticados (ao cadastrar ou salvar na biblioteca)
DROP POLICY IF EXISTS "Inserção de jogos permitida para autenticados" ON public.games;
CREATE POLICY "Inserção de jogos permitida para autenticados"
    ON public.games
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Atualização no catálogo: permitida para usuários autenticados
DROP POLICY IF EXISTS "Atualização de jogos permitida para autenticados" ON public.games;
CREATE POLICY "Atualização de jogos permitida para autenticados"
    ON public.games
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- 5. Habilitar Realtime para a tabela games
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'games'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
    END IF;
END $$;
