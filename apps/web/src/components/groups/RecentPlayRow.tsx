import { Crown, Trophy } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import type { Play } from "@/lib/groupTypes";

interface RecentPlayRowProps {
  play: Play;
  groupName?: string;
}

export function RecentPlayRow({ play, groupName }: RecentPlayRowProps) {
  const winners = play.participants.filter(p => p.is_winner);
  const winnerDisplay = play.is_cooperative
    ? play.cooperative_result === "won" ? "Victory" : "Defeat"
    : winners.map(w => w.display_name).join(", ") || null;

  return (
    <div className="flex items-center gap-3 py-2.5">
      {/* Game thumbnail */}
      <div className="w-10 h-10 rounded-lg bg-muted shrink-0 overflow-hidden">
        {play.game?.thumbnail_url ? (
          <img src={play.game.thumbnail_url} alt="" className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-[10px] font-bold text-muted-foreground">
            {play.game?.name?.charAt(0) ?? "?"}
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-[13px] font-semibold text-foreground truncate">
            {play.game?.name ?? "Unknown Game"}
          </span>
          {groupName && (
            <span className="text-[9px] font-medium px-1.5 py-[1px] rounded-full bg-primary/10 text-primary shrink-0">
              {groupName}
            </span>
          )}
        </div>
        <div className="flex items-center gap-1.5 mt-0.5">
          {winnerDisplay && (
            <span className="flex items-center gap-0.5 text-[11px] text-muted-foreground">
              {play.is_cooperative ? (
                <Trophy className="w-[10px] h-[10px] text-accent" />
              ) : (
                <Crown className="w-[10px] h-[10px] text-accent" />
              )}
              {winnerDisplay}
            </span>
          )}
          <span className="text-[10px] text-muted-foreground/60">
            {formatDistanceToNow(new Date(play.played_at), { addSuffix: true })}
          </span>
        </div>
      </div>
    </div>
  );
}
