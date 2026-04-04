import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";
import { fetchFromBGG, parseThingResponse } from "../_shared/bgg.ts";

interface BulkImportRequest {
  start_id: number;
  end_id: number;
  batch_size?: number;
  ids?: number[];
  only_missing?: boolean;
}

serve(async (req) => {
  try {
    const { start_id, end_id, batch_size = 20, ids, only_missing = false }: BulkImportRequest = await req.json();

    const size = Math.max(1, Math.min(batch_size, 20));
    const db = createServiceClient();

    let requestedIds = 0;
    let importedGames = 0;
    const idQueue: number[] = [];

    if (ids && ids.length > 0) {
      for (const id of ids) {
        if (Number.isInteger(id) && id > 0) idQueue.push(id);
      }
      if (idQueue.length === 0) {
        return jsonResponse({ error: "ids must contain positive integers" }, 400);
      }
    } else {
      if (!Number.isInteger(start_id) || !Number.isInteger(end_id) || start_id <= 0 || end_id < start_id) {
        return jsonResponse({ error: "Invalid start_id/end_id" }, 400);
      }
      if (only_missing) {
        const { data: existingRows, error } = await db
          .from("games")
          .select("bgg_id")
          .gte("bgg_id", start_id)
          .lte("bgg_id", end_id);
        if (error) {
          throw new Error(`Failed to query existing IDs: ${error.message}`);
        }
        const existing = new Set<number>(
          (existingRows || [])
            .map((row: { bgg_id: number | null }) => row.bgg_id)
            .filter((id): id is number => Number.isInteger(id)),
        );
        for (let id = start_id; id <= end_id; id++) {
          if (!existing.has(id)) idQueue.push(id);
        }
      } else {
        for (let id = start_id; id <= end_id; id++) {
          idQueue.push(id);
        }
      }
    }

    for (let cursor = 0; cursor < idQueue.length; cursor += size) {
      const batchIds = idQueue.slice(cursor, cursor + size);
      requestedIds += batchIds.length;

      const xml = await fetchThingWithRetry(batchIds.join(","));
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
        importedGames += 1;
      }
    }

    return jsonResponse({
      start_id,
      end_id,
      only_missing,
      ids_count: ids?.length ?? null,
      requested_ids: requestedIds,
      imported_games: importedGames,
    });
  } catch (error) {
    console.error("bgg-bulk-import error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function fetchThingWithRetry(ids: string): Promise<string> {
  const maxRetries = 5;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fetchFromBGG("/thing", { id: ids, stats: "1" });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const isRateLimited = message.includes("429");
      if (!isRateLimited || attempt === maxRetries) {
        throw error;
      }
      await sleep((attempt + 1) * 5000);
    }
  }
  throw new Error("unreachable");
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
