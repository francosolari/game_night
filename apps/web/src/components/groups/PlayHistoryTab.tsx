import { useState, useMemo } from "react";
import { Trash2, Crown, Trophy } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import type { Play, PlayFilterMode, GroupMember } from "@/lib/groupTypes";
import { filterPlays } from "@/lib/groupTypes";

interface PlayHistoryTabProps {
  plays: Play[];
  members: GroupMember[];
  onDelete?: (playId: string) => void;
}

export function PlayHistoryTab({ plays, members, onDelete }: PlayHistoryTabProps) {
  const [mode, setMode] = useState<PlayFilterMode>("all");
  const [selectedMemberIds, setSelectedMemberIds] = useState<Set<string>>(new Set());

  const filtered = useMemo(() => filterPlays(plays, mode, members, selectedMemberIds), [plays, mode, members, selectedMemberIds]);

  const toggleMember = (userId: string) => {
    setSelectedMemberIds(prev => {
      const next = new Set(prev);
      if (next.has(userId)) next.delete(userId);
      else next.add(userId);
      return next;
    });
  };

  return (
    <div className="space-y-4">
      {/* Filter bar */}
      <div className="flex gap-1 bg-muted/60 p-1 rounded-xl">
        {(["all", "groupNights", "custom"] as PlayFilterMode[]).map(m => (
          <button
            key={m}
            onClick={() => setMode(m)}
            className={`flex-1 text-xs font-medium py-1.5 rounded-lg transition-colors ${mode === m ? "bg-card text-foreground shadow-sm" : "text-muted-foreground"}`}
          >
            {m === "all" ? "All" : m === "groupNights" ? "Group Nights" : "Custom"}
          </button>
        ))}
      </div>

      {/* Custom member chips */}
      {mode === "custom" && (
        <div className="flex flex-wrap gap-1.5">
          {members.filter(m => m.user_id).map(m => (
            <button
              key={m.id}
              onClick={() => m.user_id && toggleMember(m.user_id)}
              className={`text-[11px] font-medium px-2.5 py-1 rounded-full transition-colors ${m.user_id && selectedMemberIds.has(m.user_id) ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"}`}
            >
              {m.display_name || "Unknown"}
            </button>
          ))}
        </div>
      )}

      {/* Play list */}
      {filtered.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">No plays logged yet</p>
      ) : (
        <div className="space-y-2">
          {filtered.map(play => (
            <PlayCard key={play.id} play={play} onDelete={onDelete} />
          ))}
        </div>
      )}
    </div>
  );
}

function PlayCard({ play, onDelete }: { play: Play; onDelete?: (id: string) => void }) {
  const winners = play.participants.filter(p => p.is_winner);

  return (
    <div className="flex items-start gap-3 p-3 rounded-xl bg-card border border-border/40">
      <div className="w-12 h-12 rounded-lg bg-muted shrink-0 overflow-hidden">
        {play.game?.thumbnail_url ? (
          <img src={play.game.thumbnail_url} alt="" className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-xs font-bold text-muted-foreground">
            {play.game?.name?.charAt(0) ?? "?"}
          </div>
        )}
      </div>
      <div className="flex-1 min-w-0">
        <h4 className="text-[13px] font-bold text-foreground">{play.game?.name ?? "Unknown"}</h4>
        <p className="text-[11px] text-muted-foreground mt-0.5">
          {play.participants.map(p => p.display_name).join(", ")}
        </p>
        {(winners.length > 0 || play.is_cooperative) && (
          <div className="flex items-center gap-1 mt-1">
            {play.is_cooperative ? (
              <>
                <Trophy className="w-3 h-3 text-accent" />
                <span className="text-[11px] font-medium text-accent">
                  {play.cooperative_result === "won" ? "Victory" : "Defeat"}
                </span>
              </>
            ) : (
              <>
                <Crown className="w-3 h-3 text-accent" />
                <span className="text-[11px] font-medium text-accent">
                  {winners.map(w => w.display_name).join(", ")}
                </span>
              </>
            )}
          </div>
        )}
      </div>
      <div className="flex flex-col items-end gap-1">
        <span className="text-[10px] text-muted-foreground">
          {formatDistanceToNow(new Date(play.played_at), { addSuffix: true })}
        </span>
        {onDelete && (
          <button onClick={() => onDelete(play.id)} className="p-1 rounded hover:bg-destructive/10 transition-colors">
            <Trash2 className="w-3.5 h-3.5 text-destructive/60" />
          </button>
        )}
      </div>
    </div>
  );
}
