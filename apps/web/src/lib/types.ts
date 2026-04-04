// Mirrors iOS Models — GameEvent, Invite, Game, User, TimeOption, EventGame

export interface User {
  id: string;
  phone_number: string;
  display_name: string;
  avatar_url?: string | null;
  bio?: string | null;
  bgg_username?: string | null;
  phone_visible: boolean;
  discoverable_by_phone: boolean;
  marketing_opt_in: boolean;
  contacts_synced: boolean;
  phone_verified: boolean;
  privacy_accepted_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface Game {
  id: string;
  owner_id?: string | null;
  bgg_id?: number | null;
  name: string;
  year_published?: number | null;
  thumbnail_url?: string | null;
  image_url?: string | null;
  min_players: number;
  max_players: number;
  recommended_players?: number[] | null;
  min_playtime: number;
  max_playtime: number;
  complexity: number;
  bgg_rating?: number | null;
  description?: string | null;
  categories: string[];
  mechanics: string[];
  designers: string[];
  publishers: string[];
  artists: string[];
  min_age?: number | null;
  bgg_rank?: number | null;
}

export interface EventGame {
  id: string;
  game_id: string;
  game?: Game | null;
  is_primary: boolean;
  sort_order: number;
  yes_count: number;
  maybe_count: number;
  no_count: number;
}

export interface TimeOption {
  id: string;
  event_id?: string | null;
  date: string;
  start_time: string;
  end_time?: string | null;
  label?: string | null;
  is_suggested: boolean;
  suggested_by?: string | null;
  vote_count: number;
  maybe_count: number;
}

export type EventStatus = "draft" | "published" | "confirmed" | "in_progress" | "completed" | "cancelled";
export type EventVisibility = "private" | "public" | "unlisted";
export type InviteStatusType = "pending" | "accepted" | "declined" | "maybe" | "expired" | "waitlisted";

export interface InviteStrategy {
  type: "all_at_once" | "tiered";
  tier_size?: number | null;
  auto_promote: boolean;
}

export interface DraftInvitee {
  id: string;
  name: string;
  phone_number: string;
  user_id?: string | null;
  tier: number;
  group_id?: string | null;
  group_emoji?: string | null;
  group_name?: string | null;
}

export interface GameEvent {
  id: string;
  host_id: string;
  host?: User | null;
  title: string;
  description?: string | null;
  visibility: EventVisibility;
  rsvp_deadline?: string | null;
  allow_guest_invites: boolean;
  location?: string | null;
  location_address?: string | null;
  status: EventStatus;
  games: EventGame[];
  time_options: TimeOption[];
  confirmed_time_option_id?: string | null;
  allow_time_suggestions: boolean;
  schedule_mode: "fixed" | "poll";
  invite_strategy: InviteStrategy;
  min_players: number;
  max_players?: number | null;
  allow_game_voting: boolean;
  confirmed_game_id?: string | null;
  plus_one_limit: number;
  allow_maybe_rsvp: boolean;
  require_plus_one_names: boolean;
  cover_image_url?: string | null;
  cover_variant: number;
  draft_invitees?: DraftInvitee[] | null;
  deleted_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface Invite {
  id: string;
  event_id: string;
  host_user_id?: string | null;
  user_id?: string | null;
  phone_number: string;
  display_name?: string | null;
  status: InviteStatusType;
  tier: number;
  tier_position: number;
  is_active: boolean;
  responded_at?: string | null;
  selected_time_option_ids: string[];
  suggested_times?: TimeOption[] | null;
  sent_via: "push" | "sms" | "both";
  sms_delivery_status?: string | null;
  created_at: string;
}

// Activity Feed
export type ActivityType = "comment" | "rsvp_update" | "announcement" | "date_confirmed" | "game_confirmed";

export interface ActivityFeedItem {
  id: string;
  event_id: string;
  user_id: string;
  user?: User | null;
  type: ActivityType;
  content?: string | null;
  parent_id?: string | null;
  is_pinned: boolean;
  created_at: string;
  updated_at: string;
  replies?: ActivityFeedItem[];
}

export type GameVoteType = "yes" | "maybe" | "no";

export interface GameVote {
  id: string;
  event_id: string;
  game_id: string;
  user_id: string;
  vote_type: GameVoteType;
  created_at: string;
}

export interface TimeOptionVoter {
  time_option_id: string;
  vote_type: string;
  user_id: string;
  display_name: string;
  avatar_url: string | null;
}

export interface GameVoterInfo {
  game_id: string;
  vote_type: string;
  user_id: string;
  display_name: string;
  avatar_url: string | null;
}

export interface InviteUser {
  id: string;
  name: string;
  avatarUrl: string | null;
  status: InviteStatusType;
  tier: number;
}

export interface InviteSummary {
  total: number;
  accepted: number;
  declined: number;
  pending: number;
  maybe: number;
  waitlisted: number;
  acceptedUsers: InviteUser[];
  pendingUsers: InviteUser[];
  maybeUsers: InviteUser[];
  declinedUsers: InviteUser[];
  waitlistedUsers: InviteUser[];
}

export type EventViewerRole = "host" | "rsvpd" | "invitedNotRSVPd" | "publicViewer";

export interface EventAccessPolicy {
  visibility: EventVisibility;
  viewerRole: EventViewerRole;
  rsvpDeadline?: string | null;
  allowGuestInvites: boolean;
  canViewFullAddress: boolean;
  canViewGuestList: boolean;
  canInviteGuests: boolean;
  isRSVPClosed: boolean;
}

export function buildAccessPolicy(
  event: GameEvent,
  viewerRole: EventViewerRole
): EventAccessPolicy {
  const canViewFullAddress = event.visibility === "public" || viewerRole === "host" || viewerRole === "rsvpd";
  const canViewGuestList = viewerRole !== "publicViewer";
  const isRSVPClosed = event.rsvp_deadline ? new Date(event.rsvp_deadline) < new Date() : false;
  const canInviteGuests =
    viewerRole === "host" ||
    (viewerRole === "rsvpd" && event.allow_guest_invites);

  return {
    visibility: event.visibility,
    viewerRole,
    rsvpDeadline: event.rsvp_deadline,
    allowGuestInvites: event.allow_guest_invites,
    canViewFullAddress,
    canViewGuestList,
    canInviteGuests,
    isRSVPClosed,
  };
}

// Helper functions matching iOS logic
export function getEffectiveStartDate(event: GameEvent): Date {
  if (event.confirmed_time_option_id) {
    const confirmed = event.time_options.find(t => t.id === event.confirmed_time_option_id);
    if (confirmed) return new Date(confirmed.start_time);
  }
  if (event.time_options.length > 0) {
    const earliest = event.time_options.reduce((min, t) =>
      new Date(t.start_time) < new Date(min.start_time) ? t : min
    );
    return new Date(earliest.start_time);
  }
  return new Date(event.created_at);
}

export function getPreferredCoverImage(event: GameEvent): string | null {
  if (event.cover_image_url) return event.cover_image_url;
  const primary = event.games.find(g => g.is_primary);
  if (primary?.game?.image_url) return primary.game.image_url;
  if (event.games[0]?.game?.image_url) return event.games[0].game.image_url;
  return null;
}

export function buildInviteSummary(invites: Invite[], event: GameEvent): InviteSummary {
  const nonHostInvites = invites.filter(inv => inv.user_id !== event.host_id);

  const mapUsers = (list: Invite[]): InviteUser[] =>
    list.map(inv => ({
      id: inv.id,
      name: inv.display_name || "Unknown",
      avatarUrl: null,
      status: inv.status,
      tier: inv.tier,
    }));

  const accepted = nonHostInvites.filter(i => i.status === "accepted");
  const declined = nonHostInvites.filter(i => i.status === "declined");
  const pending = nonHostInvites.filter(i => i.status === "pending");
  const maybe = nonHostInvites.filter(i => i.status === "maybe");
  const waitlisted = nonHostInvites.filter(i => i.status === "waitlisted");

  // Add host as accepted
  const hostUser: InviteUser = {
    id: event.host_id,
    name: event.host?.display_name || "Host",
    avatarUrl: event.host?.avatar_url || null,
    status: "accepted",
    tier: 1,
  };

  return {
    total: nonHostInvites.length + 1,
    accepted: accepted.length + 1,
    declined: declined.length,
    pending: pending.length,
    maybe: maybe.length,
    waitlisted: waitlisted.length,
    acceptedUsers: [hostUser, ...mapUsers(accepted)],
    pendingUsers: mapUsers(pending),
    maybeUsers: mapUsers(maybe),
    declinedUsers: mapUsers(declined),
    waitlistedUsers: mapUsers(waitlisted),
  };
}

// ─── Game Library Types ───

export interface GameLibraryEntry {
  id: string;
  user_id: string;
  game_id: string;
  game?: Game | null;
  category_id?: string | null;
  rating?: number | null;
  play_count: number;
  added_at: string;
  notes?: string | null;
}

export interface GameCategory {
  id: string;
  user_id: string;
  name: string;
  icon?: string | null;
  sort_order: number;
  is_default: boolean;
  created_at: string;
}

export interface GameFamily {
  id: string;
  name: string;
  bgg_family_id: number;
}

// ─── Game Helper Functions ───

export function complexityLabel(weight: number): string {
  if (weight <= 1.5) return "Light";
  if (weight <= 2.0) return "Light-Medium";
  if (weight <= 3.0) return "Medium";
  if (weight <= 3.5) return "Medium-Heavy";
  return "Heavy";
}

export function complexityColorClass(weight: number): string {
  if (weight <= 2.0) return "bg-green-500/10 text-green-600";
  if (weight <= 3.5) return "bg-amber-500/10 text-amber-600";
  return "bg-red-500/10 text-red-600";
}

export function ratingColorClass(rating: number): string {
  if (rating >= 8.5) return "text-green-600";
  if (rating >= 7.0) return "text-lime-600";
  if (rating >= 4.0) return "text-amber-600";
  return "text-red-600";
}

export function playerCountDisplay(game: Game): string {
  if (game.min_players === game.max_players) return `${game.min_players} players`;
  return `${game.min_players}–${game.max_players} players`;
}

export function playtimeDisplay(game: Game): string {
  if (game.min_playtime === game.max_playtime) return `${game.min_playtime} min`;
  return `${game.min_playtime}–${game.max_playtime} min`;
}

export function formatPlayerRanges(values?: number[] | null): string | null {
  if (!values || values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);

  const ranges: string[] = [];
  let start = sorted[0];
  let end = sorted[0];

  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i] === end + 1) {
      end = sorted[i];
    } else {
      ranges.push(start === end ? `${start}` : `${start}–${end}`);
      start = sorted[i];
      end = sorted[i];
    }
  }
  ranges.push(start === end ? `${start}` : `${start}–${end}`);
  return ranges.join(", ");
}

// ─── Notification Types ───

export type NotificationType =
  | "invite_received"
  | "rsvp_update"
  | "group_invite"
  | "time_confirmed"
  | "bench_promoted"
  | "dm_received"
  | "text_blast"
  | "game_confirmed"
  | "event_cancelled";

export interface AppNotification {
  id: string;
  user_id: string;
  type: NotificationType;
  title: string;
  body?: string | null;
  metadata?: Record<string, any> | null;
  event_id?: string | null;
  invite_id?: string | null;
  group_id?: string | null;
  conversation_id?: string | null;
  read_at?: string | null;
  created_at: string;
  event?: GameEvent | null;
}

// ─── Direct Messaging Types ───

export interface ConversationSummary {
  conversation_id: string;
  other_user_id: string;
  other_display_name: string | null;
  other_avatar_url: string | null;
  last_message_content: string | null;
  last_message_type: string | null;
  last_message_at: string | null;
  unread_count: number;
}

export interface DirectMessage {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string | null;
  message_type: string;
  metadata?: MessageMetadata | null;
  created_at: string;
  sender?: {
    id: string;
    display_name: string;
    avatar_url?: string | null;
  } | null;
}

export interface MessageMetadata {
  event_id?: string | null;
  invite_id?: string | null;
  event_title?: string | null;
  cover_image_url?: string | null;
  host_name?: string | null;
  time_label?: string | null;
  invite_token?: string | null;
}
