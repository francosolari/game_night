import type { GameGroup } from "@/lib/groupTypes";

interface GroupBubbleProps {
  group: GameGroup;
  onClick?: () => void;
}

export function GroupBubble({ group, onClick }: GroupBubbleProps) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col items-center gap-1.5 w-[72px] shrink-0 active:scale-95 transition-transform"
    >
      <div className="w-14 h-14 rounded-full bg-gradient-to-br from-primary/30 to-accent/30 flex items-center justify-center text-xl border-2 border-primary/20">
        {group.emoji || group.name.charAt(0).toUpperCase()}
      </div>
      <span className="text-[11px] font-medium text-foreground leading-tight text-center line-clamp-1 w-full">
        {group.name}
      </span>
      <span className="text-[9px] text-muted-foreground -mt-1">
        {group.members.length} {group.members.length === 1 ? "member" : "members"}
      </span>
    </button>
  );
}

export function NewGroupBubble({ onClick }: { onClick?: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col items-center gap-1.5 w-[72px] shrink-0 active:scale-95 transition-transform"
    >
      <div className="w-14 h-14 rounded-full border-2 border-dashed border-muted-foreground/40 flex items-center justify-center">
        <svg viewBox="0 0 24 24" className="w-5 h-5 text-muted-foreground" fill="none" stroke="currentColor" strokeWidth={2}>
          <line x1="12" y1="5" x2="12" y2="19" />
          <line x1="5" y1="12" x2="19" y2="12" />
        </svg>
      </div>
      <span className="text-[11px] font-medium text-muted-foreground leading-tight">New</span>
    </button>
  );
}
