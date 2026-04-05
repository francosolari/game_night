-- Optimize game library reads by providing a direct index for the primary ordering pattern.
-- This reduces sort pressure on the DB when users with many games open the Games tab.

CREATE INDEX IF NOT EXISTS idx_game_library_user_added_at_desc 
ON public.game_library (user_id, added_at DESC);

-- Also optimize categories fetch for the filter chips
CREATE INDEX IF NOT EXISTS idx_game_categories_user_sort 
ON public.game_categories (user_id, sort_order ASC);
