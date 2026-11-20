-- Migração Supabase: Tabela de Biblioteca de Jogos Pessoal com RLS Privado
-- Arquivo: supabase/migrations/20261119_create_library_entries.sql

-- 1. Criação da tabela de entradas da biblioteca
CREATE TABLE IF NOT EXISTS public.library_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT,
    user_email TEXT,
    game_id INTEGER NOT NULL,
    game_name TEXT NOT NULL,
    game_data JSONB NOT NULL,
    status TEXT NOT NULL,
    notes TEXT,
    user_rating INTEGER CHECK (user_rating IS NULL OR (user_rating >= 1 AND user_rating <= 10)),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_game UNIQUE (user_id, game_id)
);

-- Índices para otimização de consultas e ordenação
CREATE INDEX IF NOT EXISTS idx_library_entries_user_id ON public.library_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_library_entries_game_id ON public.library_entries(game_id);
CREATE INDEX IF NOT EXISTS idx_library_entries_status ON public.library_entries(status);
CREATE INDEX IF NOT EXISTS idx_library_entries_updated_at ON public.library_entries(updated_at DESC);

-- Trigger para atualizar automaticamente o campo updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_library_entries_updated_at ON public.library_entries;
CREATE TRIGGER trigger_library_entries_updated_at
    BEFORE UPDATE ON public.library_entries
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 2. Configuração de Row Level Security (RLS) - Biblioteca Pessoal e Privada
ALTER TABLE public.library_entries ENABLE ROW LEVEL SECURITY;

-- Política 1: Leitura permitida apenas para o próprio usuário autenticado
DROP POLICY IF EXISTS "Leitura compartilhada para usuários autenticados" ON public.library_entries;
DROP POLICY IF EXISTS "Leitura permitida apenas para o próprio usuário" ON public.library_entries;
CREATE POLICY "Leitura permitida apenas para o próprio usuário"
    ON public.library_entries
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Política 2: Usuários autenticados podem inserir jogos em sua própria biblioteca
DROP POLICY IF EXISTS "Inserção permitida para o próprio usuário" ON public.library_entries;
CREATE POLICY "Inserção permitida para o próprio usuário"
    ON public.library_entries
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Política 3: Usuários podem atualizar apenas seus próprios registros
DROP POLICY IF EXISTS "Atualização permitida para o próprio usuário" ON public.library_entries;
CREATE POLICY "Atualização permitida para o próprio usuário"
    ON public.library_entries
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Política 4: Usuários podem remover apenas seus próprios registros
DROP POLICY IF EXISTS "Remoção permitida para o próprio usuário" ON public.library_entries;
CREATE POLICY "Remoção permitida para o próprio usuário"
    ON public.library_entries
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 3. Habilitação de publicações Realtime no Supabase
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'library_entries'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.library_entries;
    END IF;
END $$;
