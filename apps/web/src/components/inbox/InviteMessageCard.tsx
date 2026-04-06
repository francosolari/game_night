import { Dice5, ChevronRight } from "lucide-react";
import type { MessageMetadata } from "@/lib/types";

interface Props {
  metadata: MessageMetadata;
  onTap?: () => void;
}

export function InviteMessageCard({ metadata, onTap }: Props) {
  return (
    <button
      onClick={onTap}
      className="w-full flex items-center gap-3 p-3 rounded-xl bg-card border border-border/60 hover:bg-muted/40 transition-colors text-left"
    >
      {/* Thumbnail */}
      {metadata.cover_image_url ? (
        <img
          src={metadata.cover_image_url}
          alt=""
          className="w-12 h-12 rounded-lg object-cover shrink-0"
        />
      ) : (
        <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
          <Dice5 className="w-6 h-6 text-primary" />
        </div>
      )}

      {/* Info */}
      <div className="flex-1 min-w-0">
        <p className="text-[11px] font-semibold text-primary uppercase tracking-wide">
          Game Night Invite
        </p>
        {metadata.event_title && (
          <p className="text-sm font-bold text-foreground truncate">{metadata.event_title}</p>
        )}
        {metadata.time_label && (
          <p className="text-[12px] text-muted-foreground truncate">{metadata.time_label}</p>
        )}
        {metadata.host_name && (
          <p className="text-[12px] text-muted-foreground">Hosted by {metadata.host_name}</p>
        )}
      </div>

      <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0" />
    </button>
  );
}
