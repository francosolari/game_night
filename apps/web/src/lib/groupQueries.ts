import { supabase } from "@/lib/supabase";
import type { GameGroup, GroupMember, Play, GroupMessage } from "./groupTypes";
import type { GameEvent } from "./types";

const EVENT_LIST_SELECT =
  "id,host_id,title,description,visibility,rsvp_deadline,allow_guest_invites,location,location_address,status,games:event_games(id,event_id,game_id,is_primary,sort_order,yes_count,maybe_count,no_count,game:games(id,name,image_url,thumbnail_url,min_players,max_players,min_playtime,max_playtime,complexity,bgg_rating)),time_options!event_id(id,event_id,date,start_time,end_time,label,is_suggested,suggested_by,vote_count,maybe_count,created_at),confirmed_time_option_id,allow_time_suggestions,schedule_mode,invite_strategy,min_players,max_players,allow_game_voting,confirmed_game_id,plus_one_limit,allow_maybe_rsvp,require_plus_one_names,cover_image_url,cover_variant,deleted_at,created_at,updated_at,host:users(id,display_name,avatar_url)";

async function currentUserId(): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

// ─── Groups CRUD ───

export async function fetchGroups(): Promise<GameGroup[]> {
  const userId = await currentUserId();

  // Fetch groups the user owns
  const { data: ownedData, error: ownedError } = await supabase
    .from("groups")
    .select("*, members:group_members(*)")
    .eq("owner_id", userId)
    .order("created_at", { ascending: false });
  if (ownedError) throw ownedError;

  // Fetch groups the user is a member of (via group_members.user_id)
  const { data: memberRows, error: memberError } = await supabase
    .from("group_members")
    .select("group_id")
    .eq("user_id", userId);
  if (memberError) throw memberError;

  const memberGroupIds = (memberRows ?? [])
    .map(r => r.group_id)
    .filter(id => !(ownedData ?? []).some(g => g.id === id));

  let memberGroups: GameGroup[] = [];
  if (memberGroupIds.length > 0) {
    const { data: mData, error: mError } = await supabase
      .from("groups")
      .select("*, members:group_members(*)")
      .in("id", memberGroupIds)
      .order("created_at", { ascending: false });
    if (mError) throw mError;
    memberGroups = (mData ?? []) as unknown as GameGroup[];
  }

  return [...(ownedData ?? []) as unknown as GameGroup[], ...memberGroups];
}

export async function createGroup(name: string, emoji?: string, description?: string): Promise<GameGroup> {
  const userId = await currentUserId();
  const { data, error } = await supabase
    .from("groups")
    .insert({ owner_id: userId, name, emoji, description })
    .select("*, members:group_members(*)")
    .single();
  if (error) throw error;
  return data as unknown as GameGroup;
}

export async function deleteGroup(groupId: string): Promise<void> {
  const { error } = await supabase.from("groups").delete().eq("id", groupId);
  if (error) throw error;
}

export async function updateGroup(groupId: string, fields: Partial<Pick<GameGroup, "name" | "emoji" | "description">>): Promise<void> {
  const { error } = await supabase.from("groups").update(fields).eq("id", groupId);
  if (error) throw error;
}

// ─── Members ───

export async function addGroupMember(groupId: string, member: { phone_number: string; display_name: string }): Promise<GroupMember> {
  const { data, error } = await supabase
    .from("group_members")
    .insert({ group_id: groupId, phone_number: member.phone_number, display_name: member.display_name })
    .select("*")
    .single();
  if (error) throw error;
  return data as unknown as GroupMember;
}

export async function removeGroupMember(memberId: string): Promise<void> {
  const { error } = await supabase.from("group_members").delete().eq("id", memberId);
  if (error) throw error;
}

// ─── Events for Group ───

export async function fetchEventsForGroup(groupId: string): Promise<GameEvent[]> {
  // events.group_id column needed
  try {
    const { data, error } = await supabase
      .from("events")
      .select(EVENT_LIST_SELECT)
      .eq("group_id", groupId)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []) as unknown as GameEvent[];
  } catch {
    return [];
  }
}

// ─── Plays ───

export async function fetchPlaysForGroup(groupId: string): Promise<Play[]> {
  try {
    const { data, error } = await supabase
      .from("plays")
      .select("*, game:games(*), play_participants(*), logged_by_user:users!logged_by(*)")
      .eq("group_id", groupId)
      .order("played_at", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((d: any) => ({
      ...d,
      participants: d.play_participants ?? [],
    })) as Play[];
  } catch {
    return [];
  }
}

export async function fetchRecentPlaysAcrossGroups(): Promise<Play[]> {
  try {
    const userId = await currentUserId();
    const { data, error } = await supabase
      .from("plays")
      .select("*, game:games(*), play_participants(*), logged_by_user:users!logged_by(*)")
      .eq("logged_by", userId)
      .order("played_at", { ascending: false })
      .limit(5);
    if (error) throw error;
    return (data ?? []).map((d: any) => ({
      ...d,
      participants: d.play_participants ?? [],
    })) as Play[];
  } catch {
    return [];
  }
}

export async function createPlay(play: {
  group_id?: string;
  game_id: string;
  is_cooperative: boolean;
  cooperative_result?: string | null;
  notes?: string;
  participants: { display_name: string; user_id?: string; phone_number?: string; is_winner: boolean; score?: number }[];
}): Promise<void> {
  const userId = await currentUserId();
  try {
    const { data, error } = await supabase
      .from("plays")
      .insert({
        group_id: play.group_id,
        game_id: play.game_id,
        logged_by: userId,
        played_at: new Date().toISOString(),
        is_cooperative: play.is_cooperative,
        cooperative_result: play.cooperative_result,
        notes: play.notes,
      })
      .select("id")
      .single();
    if (error) throw error;

    if (play.participants.length > 0) {
      const { error: pErr } = await supabase.from("play_participants").insert(
        play.participants.map(p => ({
          play_id: data.id,
          display_name: p.display_name,
          user_id: p.user_id,
          phone_number: p.phone_number,
          is_winner: p.is_winner,
          score: p.score,
        }))
      );
      if (pErr) throw pErr;
    }
  } catch (e) {
    console.error("createPlay failed:", e);
    throw e;
  }
}

export async function deletePlay(playId: string): Promise<void> {
  const { error } = await supabase.from("plays").delete().eq("id", playId);
  if (error) throw error;
}

// ─── Group Messages ───

export async function fetchGroupMessages(groupId: string): Promise<GroupMessage[]> {
  try {
    const { data, error } = await supabase
      .from("group_messages")
      .select("*, user:users(*)")
      .eq("group_id", groupId)
      .order("created_at", { ascending: true });
    if (error) throw error;
    return (data ?? []) as unknown as GroupMessage[];
  } catch {
    return [];
  }
}

export async function postGroupMessage(groupId: string, content: string, parentId?: string | null): Promise<void> {
  const userId = await currentUserId();
  const { error } = await supabase.from("group_messages").insert({
    group_id: groupId,
    user_id: userId,
    content,
    parent_id: parentId || null,
  });
  if (error) throw error;
}

export async function deleteGroupMessage(messageId: string): Promise<void> {
  const { error } = await supabase.from("group_messages").delete().eq("id", messageId);
  if (error) throw error;
}

export function subscribeToGroupMessages(groupId: string, onUpdate: () => void) {
  return supabase
    .channel(`group-messages-${groupId}`)
    .on("postgres_changes", { event: "*", schema: "public", table: "group_messages", filter: `group_id=eq.${groupId}` }, onUpdate)
    .subscribe();
}
