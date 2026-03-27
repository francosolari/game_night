// Edge Function: BGG Game Details with 7-day cache
// Fetches full game details from BGG /xmlapi2/thing, caches in games table
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuthenticatedUser, createServiceClient } from "../_shared/auth.ts";
import { fetchFromBGG, parseThingResponse, type ParsedGameRelations } from "../_shared/bgg.ts";

interface GamesRequest {
  bgg_ids: number[];
  include_relations?: boolean;
  force_refresh?: boolean;
}

const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

serve(async (req) => {
  try {
    await requireAuthenticatedUser(req);
    const { bgg_ids, include_relations = false, force_refresh = false }: GamesRequest = await req.json();

    if (!bgg_ids || bgg_ids.length === 0) {
      return jsonResponse({ error: "bgg_ids is required" }, 400);
    }

    if (bgg_ids.length > 20) {
      return jsonResponse({ error: "Maximum 20 IDs per request (BGG API limit)" }, 400);
    }

    const db = createServiceClient();
    const cutoff = new Date(Date.now() - CACHE_TTL_MS).toISOString();

    // Check which IDs are already cached and fresh
    let cachedIds: number[] = [];
    let cachedGames: any[] = [];

    if (!force_refresh) {
      const { data } = await db
        .from("games")
        .select("*")
        .in("bgg_id", bgg_ids)
        .gte("bgg_last_synced", cutoff);

      if (data && data.length > 0) {
        cachedGames = data;
        cachedIds = data.map((g: any) => g.bgg_id);
      }
    }

    const staleIds = bgg_ids.filter((id) => !cachedIds.includes(id));

    // Fetch stale/missing from BGG
    let freshGames: any[] = [];
    if (staleIds.length > 0) {
      const ids = staleIds.join(",");
      const xml = await fetchFromBGG("/thing", { id: ids, stats: "1" });
      const parsed = parseThingResponse(xml);

      for (const result of parsed) {
        const { game, expansions, families } = result;

        // Upsert game into DB
        const { data: upserted } = await db
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
              recommended_players: game.recommended_players,
              bgg_last_synced: new Date().toISOString(),
            },
            { onConflict: "bgg_id" },
          )
          .select()
          .single();

        if (upserted) {
          freshGames.push(upserted);

          if (include_relations) {
            await upsertRelations(db, upserted.id, game.bgg_id, expansions, families);
          }
        }
      }
    }

    // Combine cached + fresh, preserving request order
    const allGames = [...cachedGames, ...freshGames];
    const gameMap = new Map(allGames.map((g) => [g.bgg_id, g]));
    const ordered = bgg_ids.map((id) => gameMap.get(id)).filter(Boolean);

    if (include_relations) {
      // Fetch relations for all returned games
      const gameIds = ordered.map((g: any) => g.id);
      const relations = await fetchRelations(db, gameIds);
      return jsonResponse({
        games: ordered.map((g: any) => ({
          ...g,
          expansion_links: relations.expansions[g.id] || [],
          family_links: relations.families[g.id] || [],
        })),
      });
    }

    return jsonResponse({ games: ordered });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("bgg-games error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function upsertRelations(
  db: any,
  gameUuid: string,
  bggId: number,
  expansions: ParsedGameRelations["expansions"],
  families: ParsedGameRelations["families"],
) {
  // Upsert expansion links
  for (const exp of expansions) {
    // Ensure expansion game exists as a stub
    const { data: expGame } = await db
      .from("games")
      .upsert(
        {
          bgg_id: exp.bgg_id,
          name: exp.name,
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
      )
      .select("id")
      .single();

    if (expGame) {
      const baseId = exp.is_inbound ? expGame.id : gameUuid;
      const expansionId = exp.is_inbound ? gameUuid : expGame.id;

      await db
        .from("game_expansions")
        .upsert(
          { base_game_id: baseId, expansion_game_id: expansionId },
          { onConflict: "base_game_id,expansion_game_id", ignoreDuplicates: true },
        );
    }
  }

  // Upsert family links
  for (const fam of families) {
    const { data: family } = await db
      .from("game_families")
      .upsert(
        { bgg_family_id: fam.bgg_family_id, name: fam.name },
        { onConflict: "bgg_family_id" },
      )
      .select("id")
      .single();

    if (family) {
      await db
        .from("game_family_members")
        .upsert(
          { family_id: family.id, game_id: gameUuid },
          { onConflict: "family_id,game_id", ignoreDuplicates: true },
        );
    }
  }
}

async function fetchRelations(db: any, gameIds: string[]) {
  const expansions: Record<string, any[]> = {};
  const families: Record<string, any[]> = {};

  if (gameIds.length === 0) return { expansions, families };

  // Fetch expansions where game is base
  const { data: expData } = await db
    .from("game_expansions")
    .select("base_game_id, expansion_game_id, expansion:games!expansion_game_id(bgg_id, name)")
    .in("base_game_id", gameIds);

  for (const row of expData || []) {
    const key = row.base_game_id;
    if (!expansions[key]) expansions[key] = [];
    expansions[key].push({
      bgg_id: row.expansion?.bgg_id,
      name: row.expansion?.name,
      is_inbound: false,
    });
  }

  // Fetch family memberships
  const { data: famData } = await db
    .from("game_family_members")
    .select("game_id, family:game_families(bgg_family_id, name)")
    .in("game_id", gameIds);

  for (const row of famData || []) {
    const key = row.game_id;
    if (!families[key]) families[key] = [];
    families[key].push({
      bgg_family_id: row.family?.bgg_family_id,
      name: row.family?.name,
    });
  }

  return { expansions, families };
}

function jsonResponse(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
