import { supabase } from "@/lib/supabase";
import type { EventGame, TimeOption } from "@/lib/types";

// ─── Events ───

export async function createEventRecord(event: Record<string, any>): Promise<any> {
  const { data, error } = await supabase
    .from("events")
    .insert(event)
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function updateEventRecord(id: string, fields: Record<string, any>): Promise<void> {
  const { error } = await supabase
    .from("events")
    .update({ ...fields, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw error;
}

// ─── Event Games ───

export async function createEventGames(
  eventId: string,
  games: { id: string; game_id: string; is_primary: boolean; sort_order: number }[]
): Promise<void> {
  if (games.length === 0) return;
  const rows = games.map(g => ({
    id: g.id,
    event_id: eventId,
    game_id: g.game_id,
    is_primary: g.is_primary,
    sort_order: g.sort_order,
  }));
  const { error } = await supabase.from("event_games").insert(rows);
  if (error) throw error;
}

export async function upsertEventGames(
  eventId: string,
  games: { id: string; game_id: string; is_primary: boolean; sort_order: number }[]
): Promise<void> {
  if (games.length === 0) return;
  const rows = games.map(g => ({
    id: g.id,
    event_id: eventId,
    game_id: g.game_id,
    is_primary: g.is_primary,
    sort_order: g.sort_order,
  }));
  const { error } = await supabase.from("event_games").upsert(rows);
  if (error) throw error;
}

export async function deleteEventGames(ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  const { error } = await supabase.from("event_games").delete().in("id", ids);
  if (error) throw error;
}

// ─── Time Options ───

export async function createTimeOptions(
  options: { id: string; event_id: string; date: string; start_time: string; end_time?: string | null; label?: string | null; is_suggested: boolean }[]
): Promise<void> {
  if (options.length === 0) return;
  const { error } = await supabase.from("time_options").insert(options);
  if (error) throw error;
}

export async function upsertTimeOptions(
  options: { id: string; event_id: string; date: string; start_time: string; end_time?: string | null; label?: string | null; is_suggested: boolean }[]
): Promise<void> {
  if (options.length === 0) return;
  const { error } = await supabase.from("time_options").upsert(options);
  if (error) throw error;
}

export async function deleteTimeOptions(ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  const { error } = await supabase.from("time_options").delete().in("id", ids);
  if (error) throw error;
}

// ─── Invites ───

export async function createInvites(
  invites: {
    id: string;
    event_id: string;
    user_id?: string | null;
    phone_number: string;
    display_name?: string | null;
    status: string;
    tier: number;
    tier_position: number;
    is_active: boolean;
    sent_via: string;
  }[]
): Promise<void> {
  if (invites.length === 0) return;
  const { error } = await supabase.from("invites").insert(invites);
  if (error) throw error;
}

export async function updateInvite(id: string, fields: Record<string, any>): Promise<void> {
  const { error } = await supabase.from("invites").update(fields).eq("id", id);
  if (error) throw error;
}

export async function deleteInvites(ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  const { error } = await supabase.from("invites").delete().in("id", ids);
  if (error) throw error;
}

// ─── Games ───

export async function upsertGame(game: Record<string, any>): Promise<any> {
  if (game.bgg_id) {
    const { data: existing } = await supabase
      .from("games")
      .select("*")
      .eq("bgg_id", game.bgg_id)
      .limit(1);

    if (existing && existing.length > 0) {
      const { data, error } = await supabase
        .from("games")
        .update(game)
        .eq("id", existing[0].id)
        .select()
        .single();
      if (error) throw error;
      return data;
    }
  }

  const { data, error } = await supabase
    .from("games")
    .insert(game)
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ─── Fetch invites for sync ───

export async function fetchInvitesForSync(eventId: string): Promise<any[]> {
  const { data, error } = await supabase
    .from("invites")
    .select("*")
    .eq("event_id", eventId);
  if (error) throw error;
  return data ?? [];
}
