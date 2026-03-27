// Edge Function: BGG Plays Import
// Imports play history from BGG into the plays table
// Manual trigger only, 24h cooldown enforced server-side
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { requireAuthenticatedUser, createServiceClient } from "../_shared/auth.ts";
import { fetchFromBGG, parsePlaysResponse, type ParsedPlay } from "../_shared/bgg.ts";

interface PlaysRequest {
  action: "import";
  username: string;
}

const COOLDOWN_MS = 24 * 60 * 60 * 1000; // 24 hours

serve(async (req) => {
  try {
    const user = await requireAuthenticatedUser(req);
    const { action, username }: PlaysRequest = await req.json();

    if (action !== "import") {
      return jsonResponse({ error: "Only 'import' action is supported" }, 400);
    }
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
      .eq("sync_type", "plays")
      .single();

    if (syncState) {
      const lastSync = new Date(syncState.last_synced_at).getTime();
      const elapsed = Date.now() - lastSync;
      if (elapsed < COOLDOWN_MS) {
        const hoursLeft = Math.ceil((COOLDOWN_MS - elapsed) / (60 * 60 * 1000));
        return jsonResponse(
          { error: `Plays were synced recently. Try again in ~${hoursLeft} hour(s).` },
          429,
        );
      }
    }

    // Build a map of bgg_username -> app user_id for participant matching
    const { data: bggUsers } = await db
      .from("users")
      .select("id, bgg_username")
      .not("bgg_username", "is", null);

    const bggUsernameMap = new Map<string, string>();
    for (const u of bggUsers || []) {
      if (u.bgg_username) {
        bggUsernameMap.set(u.bgg_username.toLowerCase(), u.id);
      }
    }

    // Determine start date for incremental sync
    const minDate = syncState?.last_synced_at
      ? new Date(syncState.last_synced_at).toISOString().slice(0, 10)
      : undefined;

    // Fetch all pages of plays
    let page = 1;
    let totalImported = 0;
    let totalSkipped = 0;
    let hasMore = true;

    while (hasMore) {
      const params: Record<string, string> = {
        username,
        subtype: "boardgame",
        page: String(page),
      };
      if (minDate) params.mindate = minDate;

      const xml = await fetchFromBGG("/plays", params);
      const { plays, total } = parsePlaysResponse(xml);

      if (plays.length === 0) break;

      for (const play of plays) {
        const result = await importSinglePlay(db, userId, play, bggUsernameMap);
        if (result === "imported") totalImported++;
        else totalSkipped++;
      }

      // BGG returns 100 per page
      hasMore = page * 100 < total;
      page++;

      // Respect rate limits between pages
      if (hasMore) {
        await new Promise((r) => setTimeout(r, 5000));
      }
    }

    // Update sync state
    await db.from("bgg_sync_state").upsert(
      {
        user_id: userId,
        sync_type: "plays",
        last_synced_at: new Date().toISOString(),
        last_bgg_username: username,
        metadata: { total_imported: totalImported, total_skipped: totalSkipped },
      },
      { onConflict: "user_id,sync_type" },
    );

    return jsonResponse({
      imported: totalImported,
      skipped: totalSkipped,
      message: `Imported ${totalImported} plays from BGG.`,
    });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error("bgg-plays error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
});

async function importSinglePlay(
  db: any,
  userId: string,
  play: ParsedPlay,
  bggUsernameMap: Map<string, string>,
): Promise<"imported" | "skipped"> {
  // Check if play already imported
  const { data: existing } = await db
    .from("plays")
    .select("id")
    .eq("bgg_play_id", play.bgg_play_id)
    .limit(1);

  if (existing && existing.length > 0) return "skipped";

  // Find or create the game
  let gameId: string;
  const { data: gameRow } = await db
    .from("games")
    .select("id")
    .eq("bgg_id", play.bgg_game_id)
    .single();

  if (gameRow) {
    gameId = gameRow.id;
  } else {
    // Create stub game
    const { data: newGame } = await db
      .from("games")
      .insert({
        bgg_id: play.bgg_game_id,
        name: play.game_name,
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
      })
      .select("id")
      .single();

    if (!newGame) return "skipped";
    gameId = newGame.id;
  }

  // Insert the play
  const { data: newPlay } = await db
    .from("plays")
    .insert({
      game_id: gameId,
      logged_by: userId,
      played_at: play.date ? `${play.date}T12:00:00Z` : new Date().toISOString(),
      duration_minutes: play.length_minutes > 0 ? play.length_minutes : null,
      quantity: play.quantity,
      location: play.location,
      incomplete: play.incomplete,
      bgg_play_id: play.bgg_play_id,
      is_cooperative: false,
    })
    .select("id")
    .single();

  if (!newPlay) return "skipped";

  // Insert participants
  if (play.players.length > 0) {
    const participants = play.players.map((p) => {
      // Try to match BGG username to app user
      const matchedUserId = p.username
        ? bggUsernameMap.get(p.username.toLowerCase()) ?? null
        : null;

      return {
        play_id: newPlay.id,
        user_id: matchedUserId,
        display_name: p.name,
        start_position: p.start_position,
        color: p.color,
        score: p.score,
        new_to_game: p.new_to_game,
        bgg_rating: p.bgg_rating,
        is_winner: p.win,
      };
    });

    await db.from("play_participants").insert(participants);
  }

  return "imported";
}

function jsonResponse(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
