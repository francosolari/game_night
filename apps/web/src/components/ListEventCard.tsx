import { format } from "date-fns";
import { MapPin, Star, CalendarDays, CheckCircle2, User } from "lucide-react";
import { GenerativeEventCover } from "./GenerativeEventCover";
import type { GameEvent, Invite, InviteStatusType } from "@/lib/types";
import { getEffectiveStartDate, getPreferredCoverImage } from "@/lib/types";

interface ListEventCardProps {
  event: GameEvent;
  myInvite?: Invite | null;
  confirmedCount: number;
  currentUserId?: string;
  onClick?: () => void;
}

const STATUS_CONFIG: Record<InviteStatusType, { label: string; color: string; bg: string }> = {
  pending: { label: "Pending", color: "text-muted-foreground", bg: "bg-muted/80" },
  accepted: { label: "Going", color: "text-primary", bg: "bg-primary/15" },
  declined: { label: "Can't Go", color: "text-destructive", bg: "bg-destructive/15" },
  maybe: { label: "Maybe", color: "text-accent", bg: "bg-accent/15" },
  expired: { label: "Expired", color: "text-muted-foreground", bg: "bg-muted/80" },
  waitlisted: { label: "Waitlisted", color: "text-accent", bg: "bg-accent/15" },
};

export function ListEventCard({ event, myInvite, confirmedCount, currentUserId, onClick }: ListEventCardProps) {
  const coverImage = getPreferredCoverImage(event);
  const effectiveDate = getEffectiveStartDate(event);
  const isHost = event.host_id === currentUserId;
  const primaryGame = event.games.find(g => g.is_primary)?.game ?? event.games[0]?.game;
  const maxPlayers = event.max_players ?? event.min_players;
  const isPast = effectiveDate < new Date();

  const badgeLabel = myInvite
    ? (isPast && myInvite.status === "accepted" ? "Went" : STATUS_CONFIG[myInvite.status].label)
    : null;

  const timeStr = format(effectiveDate, "h:mma").toLowerCase().replace(":00", "");
  const dateStr = format(effectiveDate, "EEE, MMM d");
  const isPoll = event.schedule_mode === "poll" && event.time_options.length > 1;

  return (
    <button
      onClick={onClick}
      className="group flex text-left rounded-[14px] bg-card overflow-hidden w-full active:scale-[0.98] transition-transform duration-150 border border-border/50"
      style={{ boxShadow: "0 2px 8px hsl(0 0% 0% / 0.05), 0 1px 2px hsl(0 0% 0% / 0.03)" }}
    >
      {/* Left: Cover image — 80×100 matching iOS */}
      <div className="relative shrink-0 p-1.5">
        <div className="relative overflow-hidden rounded-[10px] w-[80px] h-[100px]">
          {coverImage ? (
            <img src={coverImage} alt="" className="w-full h-full object-cover" />
          ) : (
            <GenerativeEventCover
              title={event.title}
              eventId={event.id}
              variant={event.cover_variant}
              className="w-full h-full"
            />
          )}
          {myInvite && badgeLabel && (
            <div
              className={`absolute top-1 right-1 flex items-center gap-0.5 text-[8px] font-semibold px-1.5 py-[2px] rounded-full ${STATUS_CONFIG[myInvite.status].bg} ${STATUS_CONFIG[myInvite.status].color} backdrop-blur-sm`}
            >
              {myInvite.status === "accepted" && <CheckCircle2 className="w-[8px] h-[8px]" />}
              {badgeLabel}
            </div>
          )}
        </div>
      </div>

      {/* Right: Info stack */}
      <div className="flex-1 min-w-0 py-2.5 pr-3 flex flex-col gap-[5px]">
        {/* Date */}
        <span className="inline-flex items-center gap-1 self-start text-[10px] font-semibold text-accent">
          <CalendarDays className="w-[10px] h-[10px]" />
          {isPoll ? "Poll" : `${dateStr} · ${timeStr}`}
        </span>

        {/* Title */}
        <h3 className="font-bold text-[14px] text-foreground leading-tight truncate">
          {event.title}
        </h3>

        {/* Location */}
        <div className="flex items-center gap-1 text-muted-foreground">
          <MapPin className="w-[11px] h-[11px] shrink-0" />
          <span className="text-[11px] truncate">
            {event.location || "TBD Location"}
          </span>
        </div>

        {/* Primary game */}
        {primaryGame && (
          <div className="flex items-center gap-1 text-muted-foreground">
            <Star className="w-[10px] h-[10px] shrink-0 fill-accent text-accent" />
            <span className="text-[10px] font-bold text-foreground bg-muted/60 dark:bg-muted px-1 py-[1px] rounded truncate max-w-[120px]">
              {primaryGame.name}
            </span>
            <span className="text-[10px] opacity-40">·</span>
            <span className="text-[10px] tabular-nums">
              {primaryGame.min_playtime === primaryGame.max_playtime
                ? `${primaryGame.min_playtime}m`
                : `${primaryGame.min_playtime}-${primaryGame.max_playtime}m`}
            </span>
          </div>
        )}

        <div className="flex-1" />

        {/* Footer: host + player count */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1 text-[11px] text-muted-foreground min-w-0">
            <div className="w-4 h-4 rounded-full bg-muted flex items-center justify-center shrink-0">
              <User className="w-[9px] h-[9px] text-muted-foreground" />
            </div>
            <span className="truncate">
              {isHost ? "Hosting" : event.host?.display_name ?? "Unknown"}
            </span>
          </div>
          <PlayerCountInline confirmed={confirmedCount} min={event.min_players} max={maxPlayers} />
        </div>
      </div>
    </button>
  );
}

function PlayerCountInline({ confirmed, min, max }: { confirmed: number; min: number; max: number }) {
  const effectiveMax = max || min;
  const hasQuorum = confirmed >= min;
  const isFull = confirmed >= effectiveMax;

  const colorClass = isFull
    ? "text-muted-foreground"
    : hasQuorum
      ? "text-primary"
      : "text-accent";

  const segments = Math.min(effectiveMax, 8);

  return (
    <div className="flex flex-col items-end gap-[2px]">
      <div className="flex items-center gap-[3px]">
        {hasQuorum ? (
          <CheckCircle2 className={`w-[9px] h-[9px] ${colorClass}`} />
        ) : (
          <User className={`w-[9px] h-[9px] ${colorClass}`} />
        )}
        <span className={`text-[11px] font-semibold tabular-nums ${colorClass}`}>
          {confirmed}
        </span>
        <span className="text-[10px] text-muted-foreground">of {effectiveMax}</span>
      </div>
      <div className="flex gap-[1.5px]">
        {Array.from({ length: segments }, (_, i) => {
          let segClass: string;
          if (i < confirmed) {
            segClass = isFull ? "bg-muted-foreground" : hasQuorum ? "bg-primary" : "bg-accent";
          } else if (i < min) {
            segClass = isFull ? "bg-muted-foreground/40" : hasQuorum ? "bg-primary/40" : "bg-accent/40";
          } else {
            segClass = "bg-muted-foreground/20";
          }
          return <div key={i} className={`h-[3px] w-[5px] rounded-[1px] ${segClass}`} />;
        })}
      </div>
    </div>
  );
}
