// Edge Function: BGG Search & Hot Games
// - Search: BGG fallback when local games table has no results
// - Hot: Cached daily hot games list
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuthenticatedUser, createServiceClient } from "../_shared/auth.ts";
import {
  fetchFromBGG,
  parseSearchResponse,
  parseHotResponse,
  parseThingResponse,
  type ParsedSearchResult,
  type ParsedHotGame,
} from "../_shared/bgg.ts";

interface SearchRequest {
  query?: string;
  hot?: boolean;
}

serve(async (req) => {
  try {
    await requireAuthenticatedUser(req);
    const { query, hot }: SearchRequest = await req.json();
    const db = createServiceClient();

    if (hot) {
      return await handleHotGames(db);
    }

    if (query) {
      return await handleSearch(db, query);
    }

    return jsonResponse({ error: "Provide 'query' or 'hot: true'" }, 400);
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("bgg-search error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function handleSearch(db: any, query: string): Promise<Response> {
  // Call BGG search API (this is the fallback — client already checked local DB)
  const xml = await fetchFromBGG("/search", { query, type: "boardgame" });
  const results = parseSearchResponse(xml);

  if (results.length === 0) {
    return jsonResponse({ games: [] });
  }

  // Upsert basic game stubs into games table so future local searches find them
  // Only insert if not already present (don't overwrite full details with stubs)
  for (const r of results.slice(0, 50)) {
    await db
      .from("games")
      .upsert(
        {
          bgg_id: r.bgg_id,
          name: r.name,
          year_published: r.year_published,
          min_players: 1,
          max_players: 4,
          min_playtime: 30,
          max_playtime: 60,
          complexity: 0,
          categories: [],
          mechanics: [],
          designers: [],
          publishers: [],
          artists: [],
        },
        { onConflict: "bgg_id", ignoreDuplicates: true },
      );
  }

  const topIds = Array.from(new Set(results.slice(0, 20).map((r) => r.bgg_id)));
  void hydrateGameBatch(db, topIds).catch((error) => {
    console.error("search hydration failed:", error);
  });

  // Return results for immediate display
  const games = results.slice(0, 50).map((r) => ({
    bgg_id: r.bgg_id,
    name: r.name,
    year_published: r.year_published,
    thumbnail_url: null,
  }));

  return jsonResponse({ games });
}

async function handleHotGames(db: any): Promise<Response> {
  // Check cache: if any row cached within 24h, return all cached rows
  const { data: cached } = await db
    .from("bgg_hot_games_cache")
    .select("*")
    .gte("cached_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order("rank", { ascending: true })
    .limit(1);

  if (cached && cached.length > 0) {
    const { data: allCached } = await db
      .from("bgg_hot_games_cache")
      .select("*")
      .gte("cached_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
      .order("rank", { ascending: true });

    return jsonResponse({
      games: (allCached || []).map((g: any) => ({
        bgg_id: g.bgg_id,
        name: g.name,
        year_published: g.year_published,
        thumbnail_url: g.thumbnail_url,
      })),
    });
  }

  // Fetch from BGG
  const xml = await fetchFromBGG("/hot", { type: "boardgame" });
  const hotGames = parseHotResponse(xml);

  // Replace cache
  await db.from("bgg_hot_games_cache").delete().neq("id", 0); // delete all
  if (hotGames.length > 0) {
    await db.from("bgg_hot_games_cache").insert(
      hotGames.map((g) => ({
        bgg_id: g.bgg_id,
        name: g.name,
        year_published: g.year_published,
        thumbnail_url: g.thumbnail_url,
        rank: g.rank,
        cached_at: new Date().toISOString(),
      })),
    );
  }

  // Also upsert into games table for local search
  for (const g of hotGames) {
    await db
      .from("games")
      .upsert(
        {
          bgg_id: g.bgg_id,
          name: g.name,
          year_published: g.year_published,
          thumbnail_url: g.thumbnail_url,
          min_players: 1,
          max_players: 4,
          min_playtime: 30,
          max_playtime: 60,
          complexity: 0,
          categories: [],
          mechanics: [],
          designers: [],
          publishers: [],
          artists: [],
        },
        { onConflict: "bgg_id", ignoreDuplicates: true },
      );
  }

  const hotIds = Array.from(new Set(hotGames.slice(0, 50).map((g) => g.bgg_id)));
  void hydrateGameBatch(db, hotIds).catch((error) => {
    console.error("hot-games hydration failed:", error);
  });

  return jsonResponse({
    games: hotGames.map((g) => ({
      bgg_id: g.bgg_id,
      name: g.name,
      year_published: g.year_published,
      thumbnail_url: g.thumbnail_url,
    })),
  });
}

function jsonResponse(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function hydrateGameBatch(db: any, bggIds: number[]): Promise<void> {
  const uniqueIds = Array.from(new Set(bggIds)).slice(0, 50);
  if (uniqueIds.length === 0) return;

  for (let i = 0; i < uniqueIds.length; i += 20) {
    const batch = uniqueIds.slice(i, i + 20);
    const xml = await fetchFromBGG("/thing", {
      id: batch.join(","),
      stats: "1",
    });
    const parsed = parseThingResponse(xml);

    for (const result of parsed) {
      const { game } = result;
      await db
        .from("games")
        .upsert(
          {
            bgg_id: game.bgg_id,
            name: game.name,
            year_published: game.year_published,
            thumbnail_url: game.thumbnail_url,
            image_url: game.image_url,
            min_players: game.min_players,
            max_players: game.max_players,
            min_playtime: game.min_playtime,
            max_playtime: game.max_playtime,
            complexity: game.complexity,
            bgg_rating: game.bgg_rating,
            description: game.description,
            categories: game.categories,
            mechanics: game.mechanics,
            designers: game.designers,
            publishers: game.publishers,
            artists: game.artists,
            min_age: game.min_age,
            bgg_rank: game.bgg_rank,
            bgg_last_synced: new Date().toISOString(),
          },
          { onConflict: "bgg_id" },
        );
    }
  }
}
