# BGG Interaction Bible

## Purpose
- Keep BGG traffic centralized in Supabase Edge Functions.
- Prefer local Postgres cache first; call BGG only when needed.
- Keep sync incremental so we avoid wasteful API usage.

## Components
- Client service: `GameNight/GameNight/Services/BGGService.swift`
- Shared BGG parser/fetcher: `Supabase/functions/_shared/bgg.ts`
- Search + hot cache: `Supabase/functions/bgg-search/index.ts`
- Game details cache fill: `Supabase/functions/bgg-games/index.ts`
- One-time/range import: `Supabase/functions/bgg-bulk-import/index.ts`
- Weekly incremental maintenance: `Supabase/functions/bgg-weekly-maintenance/index.ts`
- User collection import: `Supabase/functions/bgg-collection/index.ts`
- User plays import: `Supabase/functions/bgg-plays/index.ts`

## Search Flow (Local First, BGG Fallback)
1. iOS calls RPC `search_games_fuzzy(search_query, result_limit)` against `games`.
2. If local results exist, return them immediately (no BGG call).
3. If empty, iOS calls `bgg-search` edge function.
4. `bgg-search` hits BGG `/search`, returns up to 50 matches, upserts stubs to `games`, then background-hydrates top IDs with `/thing`.
5. Future searches should hit local cache more often.

## Hot Games Flow
1. iOS calls `bgg-search` with `{ "hot": true }`.
2. Function checks `bgg_hot_games_cache` for rows cached in last 24h.
3. If fresh cache exists, return cached rows.
4. Otherwise fetch `/hot`, replace cache table, and hydrate top IDs into `games`.

## Game Details Flow
- `bgg-games` accepts up to 20 IDs (BGG `/thing` batch limit).
- Uses `bgg_last_synced` with 7-day TTL:
- Fresh rows returned directly from `games`.
- Missing/stale rows fetched from BGG `/thing`, then upserted.
- Optional `include_relations` also upserts/returns expansions and families.

## One-Time Bootstrap Import
- Use `bgg-bulk-import` with explicit ID lists or ID ranges.
- Recommended strategy:
- Pull missing IDs from DB first.
- Send IDs in chunks of 20.
- Run a few workers concurrently (not too many) to balance throughput and rate limits.
- Retry only 429/5xx failures with backoff.

## Regular Sync Strategy (Efficient Calls)
- Run `bgg-weekly-maintenance` weekly.
- It does two jobs:
- Forward scan: imports next ID window from `bgg_import_state.next_scan_start` (incremental discovery of new BGG IDs).
- Targeted refresh: refreshes a capped set of likely-stale rows, prioritizing:
- `year_published IS NULL`
- `year_published >= current year` (new/unfinalized releases)
- `bgg_last_synced` older than ~180 days (or null)
- After each run, update `next_scan_start` so the next week continues from where we left off.

## Data Synced Into `games`
- Core identity: `bgg_id`, `name`, `year_published`
- Media: `thumbnail_url`, `image_url`
- Player/time: `min_players`, `max_players`, `min_playtime`, `max_playtime`, `min_age`
- Ratings/rank: `bgg_rating`, `complexity`, `bgg_rank`
- Metadata arrays: `categories`, `mechanics`, `designers`, `publishers`, `artists`
- Text: `description` (HTML stripped + entities decoded)
- Freshness: `bgg_last_synced`

## Data Hygiene
- Shared parser decodes HTML entities in names/links and strips HTML from descriptions.
- Existing dirty descriptions/entities can be cleaned by migration SQL (already added in `20260327_fuzzy_game_search.sql`).

## Rate Limit + Usage Controls
- All BGG requests go through `_shared/bgg.ts`.
- Built-in retry behavior:
- 202 queued responses: retry (collection-friendly behavior).
- 429/500/503: retry with delays.
- Functions cap batch sizes (20 IDs) to respect BGG `/thing` constraints.
- Collection/plays imports have 24h per-user cooldown via `bgg_sync_state`.

## Auth Notes
- Some functions may be deployed with `verify_jwt = false` at gateway level.
- `bgg-search`, `bgg-games`, `bgg-collection`, and `bgg-plays` still call `requireAuthenticatedUser` in code.
- `bgg-bulk-import` and `bgg-weekly-maintenance` currently do not enforce user auth in function code.

## Recommended Weekly Ops
- Keep one scheduled weekly run of `bgg-weekly-maintenance`.
- Track these metrics after each run:
- `scan_requested`, `scan_imported`
- `refresh_requested`, `refresh_imported`
- `next_scan_start`
- Periodically check cache health:
- total cached games count
- max `bgg_id` in `games`
- percent of rows with null `year_published`
