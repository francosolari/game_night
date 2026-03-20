import { supabase } from "@/lib/supabase";
import type { GameEvent, Invite } from "@/lib/types";

const EVENT_SELECT = "*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)";

export async function fetchUpcomingEvents(): Promise<GameEvent[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  // Public events
  const { data: publicEvents, error: pubErr } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("visibility", "public")
    .or("status.eq.published,status.eq.confirmed")
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (pubErr) throw pubErr;

  // My hosted events
  const { data: hostedEvents, error: hostErr } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("host_id", user.id)
    .or("status.eq.published,status.eq.confirmed")
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (hostErr) throw hostErr;

  // Merge by id
  const map = new Map<string, GameEvent>();
  for (const e of (publicEvents ?? [])) map.set(e.id, e as GameEvent);
  for (const e of (hostedEvents ?? [])) map.set(e.id, e as GameEvent);
  return Array.from(map.values());
}

export async function fetchMyInvites(): Promise<Invite[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await supabase
    .from("invites")
    .select("*")
    .eq("user_id", user.id);

  if (error) throw error;
  return (data ?? []) as Invite[];
}

export async function fetchDrafts(): Promise<GameEvent[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("host_id", user.id)
    .eq("status", "draft")
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as GameEvent[];
}

export async function fetchEventsByIds(ids: string[]): Promise<GameEvent[]> {
  if (ids.length === 0) return [];

  const { data, error } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .in("id", ids)
    .is("deleted_at", null);

  if (error) throw error;
  return (data ?? []) as GameEvent[];
}

export async function fetchAcceptedInviteCounts(eventIds: string[]): Promise<Record<string, number>> {
  if (eventIds.length === 0) return {};

  const { data, error } = await supabase
    .from("invites")
    .select("event_id")
    .in("event_id", eventIds)
    .eq("status", "accepted");

  if (error) throw error;

  const counts: Record<string, number> = {};
  for (const row of (data ?? [])) {
    counts[row.event_id] = (counts[row.event_id] ?? 0) + 1;
  }
  return counts;
}
