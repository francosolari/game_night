import { format, isToday, isTomorrow } from "date-fns";
import { MapPin, Star, Users, CalendarDays, Check, CheckCircle2, User } from "lucide-react";
import { GenerativeEventCover } from "./GenerativeEventCover";
import type { GameEvent, Invite, InviteStatusType } from "@/lib/types";
import { getEffectiveStartDate, getPreferredCoverImage } from "@/lib/types";

interface EventCardProps {
  event: GameEvent;
  myInvite?: Invite | null;
  confirmedCount: number;
  currentUserId?: string;
  onClick?: () => void;
}

const STATUS_CONFIG: Record<InviteStatusType, { label: string; icon: string; color: string; bg: string }> = {
  pending: { label: "Pending", icon: "clock", color: "text-muted-foreground", bg: "bg-muted/80" },
  accepted: { label: "Going", icon: "check", color: "text-primary", bg: "bg-primary/15" },
  declined: { label: "Can't Go", icon: "x", color: "text-destructive", bg: "bg-destructive/15" },
  maybe: { label: "Maybe", icon: "help", color: "text-accent", bg: "bg-accent/15" },
  expired: { label: "Expired", icon: "clock", color: "text-muted-foreground", bg: "bg-muted/80" },
  waitlisted: { label: "Waitlisted", icon: "clock", color: "text-accent", bg: "bg-accent/15" },
};

export function EventCard({ event, myInvite, confirmedCount, currentUserId, onClick }: EventCardProps) {
  const coverImage = getPreferredCoverImage(event);
  const effectiveDate = getEffectiveStartDate(event);
  const isHost = event.host_id === currentUserId;
  const primaryGame = event.games.find(g => g.is_primary)?.game ?? event.games[0]?.game;
  const maxPlayers = event.max_players ?? event.min_players;
  const isPast = effectiveDate < new Date();

  const badgeLabel = myInvite
    ? (isPast && myInvite.status === "accepted" ? "Went" : STATUS_CONFIG[myInvite.status].label)
    : null;

  return (
    <button
      onClick={onClick}
      className="group flex flex-col text-left rounded-[14px] bg-card overflow-hidden w-full h-[244px] active:scale-[0.97] transition-transform duration-150"
      style={{ boxShadow: "0 3px 10px hsl(0 0% 0% / 0.06), 0 1px 3px hsl(0 0% 0% / 0.04)" }}
    >
      {/* Cover image — inner rounded, with padding */}
      <div className="relative p-1.5 pb-0">
        <div className="relative overflow-hidden rounded-[10px]" style={{ height: "100px" }}>
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

          {/* Invite status badge — top right, scaled down like iOS scaleEffect(0.8) */}
          {myInvite && badgeLabel && (
            <div
              className={`absolute top-1.5 right-1.5 flex items-center gap-1 text-[9px] font-semibold px-2 py-[3px] rounded-full ${STATUS_CONFIG[myInvite.status].bg} ${STATUS_CONFIG[myInvite.status].color} backdrop-blur-sm`}
            >
              {(myInvite.status === "accepted") && (
                <CheckCircle2 className="w-[10px] h-[10px]" />
              )}
              {badgeLabel}
            </div>
          )}
        </div>
      </div>

      {/* Content */}
      <div className="px-2.5 pb-2.5 pt-1.5 flex flex-col gap-[5px] flex-1">
        {/* Date pill */}
        <DatePill date={effectiveDate} isPoll={event.schedule_mode === "poll" && event.time_options.length > 1} />

        {/* Title */}
        <h3 className="font-bold text-[13px] text-foreground leading-tight line-clamp-2">
          {event.title}
        </h3>

        {/* Location */}
        <div className="flex items-center gap-1 text-muted-foreground">
          <MapPin className="w-[11px] h-[11px] shrink-0" />
          <span className="text-[11px] truncate">
            {event.location || "TBD Location"}
          </span>
        </div>

        {/* Primary game — star + pill + playtime */}
        {primaryGame && (
          <div className="flex items-center gap-1 text-muted-foreground min-w-0 overflow-hidden">
            <Star className="w-[10px] h-[10px] shrink-0 fill-accent text-accent" />
            <span className="text-[10px] font-bold text-foreground bg-muted/60 dark:bg-muted px-1 py-[1px] rounded truncate">
              {primaryGame.name}
            </span>
            <span className="text-[10px] opacity-40 shrink-0">·</span>
            <span className="text-[10px] tabular-nums shrink-0 whitespace-nowrap">
              {primaryGame.min_playtime === primaryGame.max_playtime
                ? `${primaryGame.min_playtime}m`
                : `${primaryGame.min_playtime}-${primaryGame.max_playtime}m`}
            </span>
          </div>
        )}

        <div className="flex-1 min-h-1" />

        {/* Divider */}
        <div className="h-px bg-border/40" />

        {/* Footer: host + player count */}
        <div className="flex items-center justify-between pt-0.5">
          {/* Host */}
          <div className="flex items-center gap-1 text-[11px] text-muted-foreground min-w-0">
            <div className="w-4 h-4 rounded-full bg-muted flex items-center justify-center shrink-0">
              <User className="w-[9px] h-[9px] text-muted-foreground" />
            </div>
            <span className="truncate">
              {isHost ? "Hosting" : event.host?.display_name ?? "Unknown"}
            </span>
          </div>

          {/* Player count with segmented bar */}
          <PlayerCountCompact
            confirmed={confirmedCount}
            min={event.min_players}
            max={maxPlayers}
          />
        </div>
      </div>
    </button>
  );
}

/* ---------- Date pill ---------- */
function DatePill({ date, isPoll }: { date: Date; isPoll: boolean }) {
  const timeStr = format(date, "h:mma").toLowerCase().replace(":00", "");

  return (
    <span className="inline-flex items-center gap-1 self-start text-[10px] font-semibold text-accent bg-accent/10 dark:bg-accent/15 px-1.5 py-[2px] rounded-full">
      <CalendarDays className="w-[10px] h-[10px]" />
      {isPoll ? "Poll" : timeStr}
    </span>
  );
}

/* ---------- Player count (compact) matching iOS PlayerCountIndicator ---------- */
function PlayerCountCompact({ confirmed, min, max }: { confirmed: number; min: number; max: number }) {
  const effectiveMax = max || min;
  const hasQuorum = confirmed >= min;
  const isFull = confirmed >= effectiveMax;

  // Status color class
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
        <span className="text-[10px] text-muted-foreground">
          of {effectiveMax}
        </span>
      </div>
      {/* Segmented bar */}
      <div className="flex gap-[1.5px]">
        {Array.from({ length: segments }, (_, i) => {
          let segClass: string;
          if (i < confirmed) {
            segClass = isFull
              ? "bg-muted-foreground"
              : hasQuorum
                ? "bg-primary"
                : "bg-accent";
          } else if (i < min) {
            segClass = isFull
              ? "bg-muted-foreground/40"
              : hasQuorum
                ? "bg-primary/40"
                : "bg-accent/40";
          } else {
            segClass = "bg-muted-foreground/20";
          }
          return (
            <div key={i} className={`h-[3px] w-[5px] rounded-[1px] ${segClass}`} />
          );
        })}
      </div>
    </div>
  );
}
