import type { Game, User } from "./types";

// ─── Group Models (mirrors iOS) ───

export interface GameGroup {
  id: string;
  owner_id: string;
  name: string;
  emoji?: string | null;
  description?: string | null;
  members: GroupMember[];
  created_at: string;
  updated_at: string;
}

export interface GroupMember {
  id: string;
  group_id: string;
  user_id?: string | null;
  phone_number: string;
  display_name?: string | null;
  tier: number;
  sort_order: number;
  added_at: string;
}

// ─── Play Models ───

export type CooperativeResult = "won" | "lost";

export interface Play {
  id: string;
  event_id?: string | null;
  group_id?: string | null;
  game_id: string;
  logged_by: string;
  played_at: string;
  duration_minutes?: number | null;
  notes?: string | null;
  is_cooperative: boolean;
  cooperative_result?: CooperativeResult | null;
  bgg_play_id?: number | null;
  participants: PlayParticipant[];
  game?: Game | null;
  logged_by_user?: User | null;
  created_at: string;
  updated_at: string;
}

export interface PlayParticipant {
  id: string;
  play_id: string;
  user_id?: string | null;
  phone_number?: string | null;
  display_name: string;
  placement?: number | null;
  is_winner: boolean;
  score?: number | null;
  team?: string | null;
  created_at: string;
}

// ─── Chat ───

export interface GroupMessage {
  id: string;
  group_id: string;
  user_id: string;
  user?: User | null;
  content: string;
  parent_id?: string | null;
  created_at: string;
  updated_at: string;
  replies?: GroupMessage[];
}

// ─── Stats ───

export type PlayFilterMode = "all" | "groupNights" | "custom";

export interface PlayerStats {
  id: string;
  name: string;
  wins: number;
  totalPlays: number;
  winRate: number;
}

export interface GamePlayCount {
  id: string;
  name: string;
  thumbnailUrl?: string | null;
  count: number;
}

export interface FunStat {
  id: string;
  title: string;
  value: string;
  icon: string; // lucide icon name
}

export interface GroupStatsData {
  funStats: FunStat[];
  leaderboard: PlayerStats[];
  mostPlayed: GamePlayCount[];
}

export function computeGroupStats(plays: Play[], members: GroupMember[]): GroupStatsData {
  // Most played game
  const gameCounts = new Map<string, { name: string; thumbnailUrl?: string | null; count: number }>();
  for (const play of plays) {
    const name = play.game?.name ?? "Unknown";
    const existing = gameCounts.get(play.game_id);
    if (existing) {
      existing.count++;
    } else {
      gameCounts.set(play.game_id, { name, thumbnailUrl: play.game?.thumbnail_url, count: 1 });
    }
  }

  const mostPlayed: GamePlayCount[] = Array.from(gameCounts.entries())
    .map(([id, v]) => ({ id, ...v }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);

  // Leaderboard
  const playerMap = new Map<string, { name: string; wins: number; totalPlays: number }>();
  for (const play of plays) {
    for (const p of play.participants) {
      const key = p.user_id ?? p.display_name;
      const existing = playerMap.get(key);
      if (existing) {
        existing.totalPlays++;
        if (p.is_winner) existing.wins++;
      } else {
        playerMap.set(key, { name: p.display_name, wins: p.is_winner ? 1 : 0, totalPlays: 1 });
      }
    }
  }

  const leaderboard: PlayerStats[] = Array.from(playerMap.entries())
    .map(([id, v]) => ({ id, ...v, winRate: v.totalPlays > 0 ? v.wins / v.totalPlays : 0 }))
    .sort((a, b) => b.wins - a.wins || b.winRate - a.winRate);

  // Unique games
  const uniqueGames = new Set(plays.map(p => p.game_id)).size;

  // Fun stats
  const funStats: FunStat[] = [
    { id: "most-played", title: "Most Played", value: mostPlayed[0]?.name ?? "—", icon: "Trophy" },
    { id: "frequency", title: "Play Frequency", value: plays.length > 0 ? `${(plays.length / Math.max(members.length, 1)).toFixed(1)}/member` : "—", icon: "TrendingUp" },
    { id: "total", title: "Total Plays", value: String(plays.length), icon: "Hash" },
    { id: "unique", title: "Unique Games", value: String(uniqueGames), icon: "Layers" },
  ];

  return { funStats, leaderboard, mostPlayed };
}

export function filterPlays(
  plays: Play[],
  mode: PlayFilterMode,
  members: GroupMember[],
  selectedMemberIds?: Set<string>
): Play[] {
  if (mode === "all") return plays;

  if (mode === "groupNights") {
    const threshold = Math.ceil(members.length / 2);
    return plays.filter(p => {
      const memberUserIds = new Set(members.map(m => m.user_id).filter(Boolean));
      const presentMembers = p.participants.filter(pp => pp.user_id && memberUserIds.has(pp.user_id)).length;
      return presentMembers >= threshold;
    });
  }

  // custom — filter by selected members
  if (!selectedMemberIds || selectedMemberIds.size === 0) return plays;
  return plays.filter(p =>
    p.participants.some(pp => pp.user_id && selectedMemberIds.has(pp.user_id))
  );
}

export function buildMessageTree(messages: GroupMessage[]): GroupMessage[] {
  const map = new Map<string, GroupMessage>();
  const roots: GroupMessage[] = [];

  for (const msg of messages) {
    map.set(msg.id, { ...msg, replies: [] });
  }

  for (const msg of map.values()) {
    if (msg.parent_id && map.has(msg.parent_id)) {
      map.get(msg.parent_id)!.replies!.push(msg);
    } else {
      roots.push(msg);
    }
  }

  return roots;
}
