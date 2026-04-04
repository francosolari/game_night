// Edge Function: BGG Collection Sync
// Imports a user's BGG collection into their game library
// Manual trigger only, 24h cooldown enforced server-side
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuthenticatedUser, createServiceClient } from "../_shared/auth.ts";
import { fetchFromBGG, parseCollectionResponse } from "../_shared/bgg.ts";

interface CollectionRequest {
  username: string;
}

const COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours

serve(async (req) => {
  try {
    const user = await requireAuthenticatedUser(req);
    const { username }: CollectionRequest = await req.json();

    if (!username) {
      return jsonResponse({ error: "BGG username is required" }, 400);
    }

    const db = createServiceClient();
    const userId = user.id;

    // Check cooldown
    const { data: syncState } = await db
      .from("bgg_sync_state")
      .select("*")
      .eq("user_id", userId)
      .eq("sync_type", "collection")
      .single();

    if (syncState) {
      const lastSync = new Date(syncState.last_synced_at).getTime();
      const elapsed = Date.now() - lastSync;
      if (elapsed < COOLDOWN_MS) {
        const hoursLeft = Math.ceil((COOLDOWN_MS - elapsed) / (60 * 60 * 1000));
        return jsonResponse(
          { error: `Collection was synced recently. Try again in ~${hoursLeft} hour(s).` },
          429,
        );
      }
    }

    // Fetch collection from BGG (handles 202 retry internally)
    const xml = await fetchFromBGG("/collection", {
      username,
      own: "1",
      stats: "1",
      subtype: "boardgame",
      excludesubtype: "boardgameexpansion",
    });

    const items = parseCollectionResponse(xml);

    let addedCount = 0;
    let skippedCount = 0;

    for (const item of items) {
      // Upsert game into games table (don't overwrite full details if already present)
      const { data: game } = await db
        .from("games")
        .upsert(
          {
            bgg_id: item.bgg_id,
            name: item.name,
            year_published: item.year_published,
            thumbnail_url: item.thumbnail_url,
            image_url: item.image_url,
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

      if (!game) {
        // Game already existed, fetch its ID
        const { data: existing } = await db
          .from("games")
          .select("id")
          .eq("bgg_id", item.bgg_id)
          .single();

        if (existing) {
          await upsertLibraryEntry(db, userId, existing.id, item);
          addedCount++;
        } else {
          skippedCount++;
        }
        continue;
      }

      await upsertLibraryEntry(db, userId, game.id, item);
      addedCount++;
    }

    // Update sync state
    await db.from("bgg_sync_state").upsert(
      {
        user_id: userId,
        sync_type: "collection",
        last_synced_at: new Date().toISOString(),
        last_bgg_username: username,
        metadata: { total_items: items.length, added: addedCount, skipped: skippedCount },
      },
      { onConflict: "user_id,sync_type" },
    );

    return jsonResponse({
      total: items.length,
      added: addedCount,
      skipped: skippedCount,
      message: `Imported ${addedCount} games from BGG collection.`,
    });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("bgg-collection error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function upsertLibraryEntry(
  db: any,
  userId: string,
  gameId: string,
  item: { num_plays: number; user_rating: number | null },
) {
  await db.from("game_library").upsert(
    {
      user_id: userId,
      game_id: gameId,
      play_count: item.num_plays,
      rating: item.user_rating ? Math.round(item.user_rating) : null,
      added_at: new Date().toISOString(),
    },
    { onConflict: "user_id,game_id", ignoreDuplicates: true },
  );
}

function jsonResponse(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
