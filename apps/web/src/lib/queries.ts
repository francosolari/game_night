import { supabase } from "@/lib/supabase";
import type { GameEvent, Invite, ActivityFeedItem, GameVote, TimeOptionVoter, GameVoterInfo } from "@/lib/types";

const EVENT_LIST_SELECT =
  "id,host_id,title,description,visibility,rsvp_deadline,allow_guest_invites,location,location_address,status,games:event_games(id,event_id,game_id,is_primary,sort_order,yes_count,maybe_count,no_count,game:games(id,name,image_url,thumbnail_url,min_players,max_players,min_playtime,max_playtime,complexity,bgg_rating)),time_options!event_id(id,event_id,date,start_time,end_time,label,is_suggested,suggested_by,vote_count,maybe_count,created_at),confirmed_time_option_id,allow_time_suggestions,schedule_mode,invite_strategy,min_players,max_players,allow_game_voting,confirmed_game_id,plus_one_limit,allow_maybe_rsvp,require_plus_one_names,cover_image_url,cover_variant,deleted_at,created_at,updated_at,host:users(id,display_name,avatar_url)";

const EVENT_DETAIL_SELECT = "*, host:users(*), games:event_games(*, game:games(*)), time_options!event_id(*)";

async function resolveUserId(explicitUserId?: string): Promise<string> {
  if (explicitUserId) return explicitUserId;

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) throw new Error("Not authenticated");
  return user.id;
}

export async function fetchUpcomingEvents(userId?: string): Promise<GameEvent[]> {
  const currentUserId = await resolveUserId(userId);

  const [publicResult, hostedResult] = await Promise.all([
    supabase
      .from("events")
      .select(EVENT_LIST_SELECT)
      .eq("visibility", "public")
      .or("status.eq.published,status.eq.confirmed")
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
    supabase
      .from("events")
      .select(EVENT_LIST_SELECT)
      .eq("host_id", currentUserId)
      .or("status.eq.published,status.eq.confirmed")
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  ]);

  const { data: publicEvents, error: pubErr } = publicResult;
  const { data: hostedEvents, error: hostErr } = hostedResult;

  if (hostErr) throw hostErr;
  if (pubErr) throw pubErr;

  const map = new Map<string, GameEvent>();
  for (const e of (publicEvents ?? [])) map.set(e.id, e as unknown as GameEvent);
  for (const e of (hostedEvents ?? [])) map.set(e.id, e as unknown as GameEvent);
  return Array.from(map.values());
}

export async function fetchMyInvites(userId?: string): Promise<Invite[]> {
  const currentUserId = await resolveUserId(userId);

  const { data, error } = await supabase
    .from("invites")
    .select("*")
    .eq("user_id", currentUserId);

  if (error) throw error;
  return (data ?? []) as Invite[];
}

export async function fetchDrafts(userId?: string): Promise<GameEvent[]> {
  const currentUserId = await resolveUserId(userId);

  const { data, error } = await supabase
    .from("events")
    .select(EVENT_LIST_SELECT)
    .eq("host_id", currentUserId)
    .eq("status", "draft")
    .is("deleted_at", null)
    .order("updated_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as unknown as GameEvent[];
}

export async function fetchEventsByIds(ids: string[]): Promise<GameEvent[]> {
  if (ids.length === 0) return [];

  const { data, error } = await supabase
    .from("events")
    .select(EVENT_LIST_SELECT)
    .in("id", ids)
    .is("deleted_at", null);

  if (error) throw error;
  return (data ?? []) as unknown as GameEvent[];
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
    .select(EVENT_DETAIL_SELECT)
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
    p_votes: votes,
    p_suggested_times: [],
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

// ─── Profile Queries ───

export async function fetchUserProfile() {
  const userId = await resolveUserId();
  const { data, error } = await supabase
    .from("users")
    .select("*")
    .eq("id", userId)
    .single();
  if (error) throw error;
  return data;
}

export async function fetchEventHistory(userId: string) {
  const { data, error } = await supabase
    .from("invites")
    .select("event_id, status, events:event_id(id, title, status, cover_image_url, cover_variant, created_at, host:users(display_name))")
    .eq("user_id", userId)
    .eq("status", "accepted")
    .order("created_at", { ascending: false })
    .limit(10);
  if (error) throw error;
  return data ?? [];
}

export async function fetchProfileStats(userId: string) {
  const [hostedRes, attendedRes, gamesRes, groupsRes] = await Promise.all([
    supabase.from("events").select("id", { count: "exact", head: true }).eq("host_id", userId).is("deleted_at", null),
    supabase.from("invites").select("id", { count: "exact", head: true }).eq("user_id", userId).eq("status", "accepted"),
    supabase.from("game_library").select("id", { count: "exact", head: true }).eq("user_id", userId),
    supabase.from("groups").select("id", { count: "exact", head: true }).eq("owner_id", userId),
  ]);
  return {
    hosted: hostedRes.count ?? 0,
    attended: attendedRes.count ?? 0,
    gamesOwned: gamesRes.count ?? 0,
    groups: groupsRes.count ?? 0,
  };
}

export async function fetchBlockedUsers() {
  const userId = await resolveUserId();
  const { data, error } = await supabase
    .from("blocked_users")
    .select("id, blocked_id, blocked_phone, reason, created_at")
    .eq("blocker_id", userId);
  if (error) throw error;
  return data ?? [];
}

export async function unblockUser(id: string) {
  const { error } = await supabase.from("blocked_users").delete().eq("id", id);
  if (error) throw error;
}

export async function updateUserProfile(fields: Record<string, unknown>) {
  const userId = await resolveUserId();
  const { error } = await supabase.from("users").update(fields).eq("id", userId);
  if (error) throw error;
}
