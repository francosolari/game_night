import { formatDistanceToNow } from "date-fns";
import { FileText, Dice5, Users } from "lucide-react";
import type { GameEvent } from "@/lib/types";

interface DraftCardProps {
  draft: GameEvent;
  onClick?: () => void;
}

export function DraftCard({ draft, onClick }: DraftCardProps) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col text-left p-3 rounded-[14px] bg-card border border-accent/20 shadow-[0_4px_8px_hsl(0_0%_0%/0.08)] dark:shadow-[0_4px_8px_hsl(0_0%_0%/0.4)] hover:shadow-[0_6px_16px_hsl(0_0%_0%/0.12)] min-w-[180px] w-[180px] transition-all active:scale-[0.97] duration-150"
    >
      <div className="flex items-center justify-between w-full mb-2">
        <FileText className="w-4 h-4 text-muted-foreground" />
        <span className="text-[10px] font-semibold text-accent bg-accent/15 px-1.5 py-0.5 rounded-full">
          DRAFT
        </span>
      </div>

      <p className="text-sm font-medium text-foreground truncate w-full">
        {draft.title || "Untitled"}
      </p>

      <div className="flex items-center gap-2 mt-1.5">
        {draft.games.length > 0 && (
          <span className="flex items-center gap-0.5 text-primary text-xs">
            <Dice5 className="w-3 h-3" />
            {draft.games.length}
          </span>
        )}
        {draft.draft_invitees && draft.draft_invitees.length > 0 && (
          <span className="flex items-center gap-0.5 text-accent text-xs">
            <Users className="w-3 h-3" />
            {draft.draft_invitees.length}
          </span>
        )}
      </div>

      <p className="text-[10px] text-muted-foreground mt-1.5">
        {formatDistanceToNow(new Date(draft.updated_at), { addSuffix: true })}
      </p>

      <p className="text-xs font-medium text-primary mt-1.5">Continue</p>
    </button>
  );
}
