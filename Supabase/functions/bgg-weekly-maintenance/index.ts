import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createServiceClient } from "../_shared/auth.ts";
import { fetchFromBGG, parseThingResponse } from "../_shared/bgg.ts";

interface MaintenanceRequest {
  scan_window?: number;
  refresh_limit?: number;
  batch_size?: number;
}

serve(async (req) => {
  try {
    const { scan_window = 5000, refresh_limit = 500, batch_size = 20 }: MaintenanceRequest = await req.json().catch(() => ({}));
    const db = createServiceClient();

    const size = Math.max(1, Math.min(batch_size, 20));
    const scanWindow = Math.max(100, Math.min(scan_window, 20000));
    const refreshLimit = Math.max(50, Math.min(refresh_limit, 2000));

    const { data: existingState } = await db
      .from("bgg_import_state")
      .select("next_scan_start")
      .eq("id", "global")
      .single();

    const scanStart = existingState?.next_scan_start ?? 1;
    const scanEnd = scanStart + scanWindow - 1;

    const scanned = await importIdRange(db, scanStart, scanEnd, size);

    await db
      .from("bgg_import_state")
      .upsert(
        {
          id: "global",
          next_scan_start: scanEnd + 1,
          last_scan_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
        { onConflict: "id" },
      );

    const currentYear = new Date().getUTCFullYear();
    const staleCutoff = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000).toISOString();

    const { data: refreshCandidates } = await db
      .from("games")
      .select("bgg_id")
      .not("bgg_id", "is", null)
      .or([
        "year_published.is.null",
        `year_published.gte.${currentYear}`,
        "bgg_last_synced.is.null",
        `bgg_last_synced.lt.${staleCutoff}`,
      ].join(","))
      .order("bgg_last_synced", { ascending: true, nullsFirst: true })
      .limit(refreshLimit);

    const refreshIds = (refreshCandidates || [])
      .map((row: { bgg_id: number | null }) => row.bgg_id)
      .filter((id): id is number => Number.isInteger(id));

    const refreshed = await importIdList(db, refreshIds, size);

    return jsonResponse({
      scan_start: scanStart,
      scan_end: scanEnd,
      scan_requested: scanned.requested,
      scan_imported: scanned.imported,
      refresh_requested: refreshed.requested,
      refresh_imported: refreshed.imported,
      next_scan_start: scanEnd + 1,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("bgg-weekly-maintenance error:", message);
    return jsonResponse({ error: message }, 500);
  }
});

async function importIdRange(
  db: any,
  startId: number,
  endId: number,
  batchSize: number,
): Promise<{ requested: number; imported: number }> {
  const ids: number[] = [];
  for (let id = startId; id <= endId; id++) ids.push(id);
  return await importIdList(db, ids, batchSize);
}

async function importIdList(
  db: any,
  ids: number[],
  batchSize: number,
): Promise<{ requested: number; imported: number }> {
  let requested = 0;
  let imported = 0;

  for (let i = 0; i < ids.length; i += batchSize) {
    const batch = ids.slice(i, i + batchSize);
    if (batch.length === 0) continue;
    requested += batch.length;

    const xml = await fetchThingWithRetry(batch.join(","));
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
      imported += 1;
    }
  }

  return { requested, imported };
}

async function fetchThingWithRetry(ids: string): Promise<string> {
  const maxRetries = 5;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fetchFromBGG("/thing", { id: ids, stats: "1" });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const retriable = message.includes("429") || message.includes("500") || message.includes("503");
      if (!retriable || attempt === maxRetries) {
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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

