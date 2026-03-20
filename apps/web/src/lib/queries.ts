import { supabase } from "@/lib/supabase";
import type { GameEvent, Invite, ActivityFeedItem, GameVote, TimeOptionVoter, GameVoterInfo } from "@/lib/types";

const EVENT_SELECT = "*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)";

export async function fetchUpcomingEvents(): Promise<GameEvent[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data: publicEvents, error: pubErr } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("visibility", "public")
    .or("status.eq.published,status.eq.confirmed")
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (pubErr) throw pubErr;

  const { data: hostedEvents, error: hostErr } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("host_id", user.id)
    .or("status.eq.published,status.eq.confirmed")
    .is("deleted_at", null)
    .order("created_at", { ascending: false });

  if (hostErr) throw hostErr;

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

// ─── Event Detail Queries ───

export async function fetchEventById(id: string): Promise<GameEvent> {
  const { data, error } = await supabase
    .from("events")
    .select(EVENT_SELECT)
    .eq("id", id)
    .is("deleted_at", null)
    .single();

  if (error) throw error;
  return data as GameEvent;
}

export async function fetchInvitesForEvent(eventId: string): Promise<Invite[]> {
  const { data, error } = await supabase
    .from("invites")
    .select("*")
    .eq("event_id", eventId);

  if (error) throw error;
  return (data ?? []) as Invite[];
}

export async function fetchActivityFeed(eventId: string): Promise<ActivityFeedItem[]> {
  const { data, error } = await supabase
    .from("activity_feed")
    .select("*, user:users(*)")
    .eq("event_id", eventId)
    .order("created_at", { ascending: true });

  if (error) throw error;
  return (data ?? []) as ActivityFeedItem[];
}

export async function fetchMyGameVotes(eventId: string): Promise<GameVote[]> {
  const { data, error } = await supabase
    .from("game_votes")
    .select("*")
    .eq("event_id", eventId);

  if (error) throw error;
  return (data ?? []) as GameVote[];
}

export async function fetchTimePollVoters(eventId: string): Promise<TimeOptionVoter[]> {
  const { data, error } = await supabase.rpc("fetch_time_poll_voters", { p_event_id: eventId });
  if (error) throw error;
  return (data ?? []) as TimeOptionVoter[];
}

export async function fetchGamePollVoters(eventId: string): Promise<GameVoterInfo[]> {
  const { data, error } = await supabase.rpc("fetch_game_poll_voters", { p_event_id: eventId });
  if (error) throw error;
  return (data ?? []) as GameVoterInfo[];
}

export async function respondToInviteRPC(
  inviteId: string,
  status: string,
  votes: { time_option_id: string; vote_type: string }[] = []
): Promise<void> {
  const { error } = await supabase.rpc("respond_to_invite", {
    p_invite_id: inviteId,
    p_status: status,
    p_votes: JSON.stringify(votes),
  });
  if (error) throw error;
}

export async function postComment(eventId: string, content: string, parentId?: string | null): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("activity_feed").insert({
    event_id: eventId,
    user_id: user.id,
    type: "comment",
    content,
    parent_id: parentId || null,
    is_pinned: false,
  });
  if (error) throw error;
}

export async function postAnnouncement(eventId: string, content: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("activity_feed").insert({
    event_id: eventId,
    user_id: user.id,
    type: "announcement",
    content,
    is_pinned: false,
  });
  if (error) throw error;
}

export async function togglePinFeedItem(itemId: string, isPinned: boolean): Promise<void> {
  const { error } = await supabase
    .from("activity_feed")
    .update({ is_pinned: isPinned })
    .eq("id", itemId);
  if (error) throw error;
}

export async function upsertGameVote(eventId: string, gameId: string, voteType: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("game_votes").upsert(
    { event_id: eventId, game_id: gameId, user_id: user.id, vote_type: voteType },
    { onConflict: "event_id,game_id,user_id" }
  );
  if (error) throw error;
}

export async function deleteGameVote(eventId: string, gameId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase
    .from("game_votes")
    .delete()
    .eq("event_id", eventId)
    .eq("game_id", gameId)
    .eq("user_id", user.id);
  if (error) throw error;
}

export async function confirmTimeOptionRPC(eventId: string, timeOptionId: string): Promise<void> {
  const { error } = await supabase.rpc("confirm_time_option", {
    p_event_id: eventId,
    p_time_option_id: timeOptionId,
  });
  if (error) throw error;
}

export async function confirmGameRPC(eventId: string, gameId: string, gameName: string): Promise<void> {
  // Update event
  const { error: evErr } = await supabase
    .from("events")
    .update({ confirmed_game_id: gameId, allow_game_voting: false })
    .eq("id", eventId);
  if (evErr) throw evErr;

  // Post announcement
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    await supabase.from("activity_feed").insert({
      event_id: eventId,
      user_id: user.id,
      type: "game_confirmed",
      content: gameName,
      is_pinned: false,
    });
  }
}

export async function softDeleteEvent(eventId: string): Promise<void> {
  const { error } = await supabase
    .from("events")
    .update({ deleted_at: new Date().toISOString(), status: "cancelled" })
    .eq("id", eventId);
  if (error) throw error;
}
