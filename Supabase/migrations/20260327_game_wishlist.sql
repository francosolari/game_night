-- Game wishlist: users can wishlist games from search or BGG cache

CREATE TABLE IF NOT EXISTS public.game_wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    UNIQUE(user_id, game_id)
);

CREATE INDEX IF NOT EXISTS idx_game_wishlist_user ON public.game_wishlist(user_id);

-- RLS
ALTER TABLE public.game_wishlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own wishlist"
    ON public.game_wishlist FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can add to own wishlist"
    ON public.game_wishlist FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove from own wishlist"
    ON public.game_wishlist FOR DELETE
    USING (auth.uid() = user_id);
