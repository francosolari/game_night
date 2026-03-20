import { useMemo } from "react";
import { Trophy, TrendingUp, Hash, Layers } from "lucide-react";
import type { Play, GroupMember, GroupStatsData } from "@/lib/groupTypes";
import { computeGroupStats } from "@/lib/groupTypes";

interface StatsTabProps {
  plays: Play[];
  members: GroupMember[];
}

const ICON_MAP: Record<string, React.ReactNode> = {
  Trophy: <Trophy className="w-5 h-5" />,
  TrendingUp: <TrendingUp className="w-5 h-5" />,
  Hash: <Hash className="w-5 h-5" />,
  Layers: <Layers className="w-5 h-5" />,
};

export function StatsTab({ plays, members }: StatsTabProps) {
  const stats: GroupStatsData = useMemo(() => computeGroupStats(plays, members), [plays, members]);

  if (plays.length === 0) {
    return <p className="text-sm text-muted-foreground text-center py-8">No plays to compute stats from</p>;
  }

  return (
    <div className="space-y-6">
      {/* Fun stats horizontal scroll */}
      <div className="flex gap-3 overflow-x-auto pb-2 -mx-1 px-1 scrollbar-hide">
        {stats.funStats.map(stat => (
          <div key={stat.id} className="min-w-[130px] p-3 rounded-xl bg-card border border-border/40 shrink-0">
            <div className="text-primary mb-2">{ICON_MAP[stat.icon] ?? <Hash className="w-5 h-5" />}</div>
            <p className="text-[11px] text-muted-foreground font-medium">{stat.title}</p>
            <p className="text-sm font-bold text-foreground mt-0.5 truncate">{stat.value}</p>
          </div>
        ))}
      </div>

      {/* Leaderboard */}
      {stats.leaderboard.length > 0 && (
        <div>
          <h3 className="text-sm font-bold text-foreground mb-3">Leaderboard</h3>
          <div className="rounded-xl border border-border/40 overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-muted/40">
                  <th className="text-left py-2 px-3 text-[11px] font-semibold text-muted-foreground">#</th>
                  <th className="text-left py-2 px-3 text-[11px] font-semibold text-muted-foreground">Player</th>
                  <th className="text-right py-2 px-3 text-[11px] font-semibold text-muted-foreground">Wins</th>
                  <th className="text-right py-2 px-3 text-[11px] font-semibold text-muted-foreground">Rate</th>
                </tr>
              </thead>
              <tbody>
                {stats.leaderboard.map((p, i) => (
                  <tr key={p.id} className="border-t border-border/30">
                    <td className="py-2 px-3 text-[12px] font-bold text-muted-foreground tabular-nums">{i + 1}</td>
                    <td className="py-2 px-3 text-[12px] font-semibold text-foreground truncate max-w-[120px]">{p.name}</td>
                    <td className="py-2 px-3 text-[12px] font-bold text-primary text-right tabular-nums">{p.wins}</td>
                    <td className="py-2 px-3 text-[12px] text-muted-foreground text-right tabular-nums">{(p.winRate * 100).toFixed(0)}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Most Played Games */}
      {stats.mostPlayed.length > 0 && (
        <div>
          <h3 className="text-sm font-bold text-foreground mb-3">Most Played Games</h3>
          <div className="space-y-2">
            {stats.mostPlayed.map((g, i) => (
              <div key={g.id} className="flex items-center gap-3">
                <span className="text-[11px] font-bold text-muted-foreground w-5 text-center tabular-nums">{i + 1}</span>
                <div className="w-8 h-8 rounded-md bg-muted shrink-0 overflow-hidden">
                  {g.thumbnailUrl ? (
                    <img src={g.thumbnailUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-[9px] font-bold text-muted-foreground">
                      {g.name.charAt(0)}
                    </div>
                  )}
                </div>
                <span className="text-[13px] font-medium text-foreground flex-1 truncate">{g.name}</span>
                <span className="text-[12px] font-bold text-primary tabular-nums">{g.count}×</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
