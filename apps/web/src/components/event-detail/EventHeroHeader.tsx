import { useMemo, useState } from "react";
import { CalendarDays, MapPin, ChevronRight, Pencil, Mail, ExternalLink } from "lucide-react";
import { GenerativeEventCover } from "@/components/GenerativeEventCover";
import { PlayerCountIndicator } from "@/components/PlayerCountIndicator";
import { buildLocationPresentation, type LocationPresentation } from "@/lib/locationPresentation";
import type { GameEvent, Invite, EventAccessPolicy } from "@/lib/types";
import { getPreferredCoverImage } from "@/lib/types";

interface Props {
  event: GameEvent;
  myInvite: Invite | null;
  confirmedCount: number;
  hasPollsActive: boolean;
  accessPolicy?: EventAccessPolicy | null;
  onRSVPTap?: () => void;
}

function getRelativeDay(dateStr: string): string {
  const d = new Date(dateStr);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const target = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diff = (target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24);
  if (diff === 0) return "Today";
  if (diff === 1) return "Tomorrow";
  return "";
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" });
}

export function EventHeroHeader({ event, myInvite, confirmedCount, hasPollsActive, accessPolicy, onRSVPTap }: Props) {
  const coverImage = getPreferredCoverImage(event);
  const firstTimeOption = event.time_options[0];
  const confirmedOption = event.confirmed_time_option_id
    ? event.time_options.find(t => t.id === event.confirmed_time_option_id)
    : null;
  const displayOption = confirmedOption || (event.schedule_mode === "fixed" ? firstTimeOption : null);

  const relativeDay = displayOption ? getRelativeDay(displayOption.start_time) : "";
  const isUrgent = relativeDay === "Today" || relativeDay === "Tomorrow";

  const isCompleted = event.status === "completed" || event.status === "cancelled";

  const [showMapMenu, setShowMapMenu] = useState(false);

  const locationPres = useMemo<LocationPresentation | null>(() => {
    return buildLocationPresentation(
      event.location,
      event.location_address,
      accessPolicy?.canViewFullAddress ?? false
    );
  }, [event.location, event.location_address, accessPolicy?.canViewFullAddress]);

  const rsvpStatusConfig = useMemo(() => {
    if (!myInvite) return null;
    if (isCompleted) {
      if (myInvite.status === "accepted") return { label: "Went", color: "text-green-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-green-500">✓</span>, isPending: false };
      if (myInvite.status === "maybe") return { label: "Maybe", color: "text-amber-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-amber-500">?</span>, isPending: false };
      if (myInvite.status === "declined") return { label: "Didn't Go", color: "text-red-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-red-500">✕</span>, isPending: false };
      return { label: "Missed", color: "text-muted-foreground", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-muted-foreground">—</span>, isPending: false };
    }
    switch (myInvite.status) {
      case "pending": return { label: hasPollsActive ? "RSVP & Vote" : "RSVP", color: "text-primary", icon: <Mail className="w-3.5 h-3.5" />, isPending: true };
      case "accepted": return { label: "Going", color: "text-green-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-green-500">✓</span>, isPending: false };
      case "maybe": return { label: "Maybe", color: "text-amber-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-amber-500">?</span>, isPending: false };
      case "declined": return { label: "Can't Go", color: "text-red-500", icon: <span className="w-3.5 h-3.5 inline-flex items-center justify-center text-red-500">✕</span>, isPending: false };
      default: return null;
    }
  }, [myInvite, hasPollsActive, isCompleted]);

  return (
    <div className="relative w-full h-[330px] md:h-[280px] md:rounded-xl md:overflow-hidden">
      {/* Cover */}
      {coverImage ? (
        <img src={coverImage} alt="" className="absolute inset-0 w-full h-full object-cover" />
      ) : (
        <GenerativeEventCover title={event.title} eventId={event.id} variant={event.cover_variant} className="absolute inset-0 w-full h-full" />
      )}

      {/* Frosted glass scrim */}
      <div className="absolute inset-0" style={{
        background: "linear-gradient(to bottom, transparent 0%, transparent 35%, rgba(0,0,0,0.6) 55%, rgba(0,0,0,0.85) 68%)",
      }} />
      <div className="absolute inset-0 backdrop-blur-[1px]" style={{
        mask: "linear-gradient(to bottom, transparent 40%, black 65%)",
        WebkitMask: "linear-gradient(to bottom, transparent 40%, black 65%)",
      }} />

      {/* Content overlay */}
      <div className="absolute bottom-0 left-0 right-0 px-5 pb-5 space-y-1">
        {/* Title */}
        <h1 className="text-2xl font-bold text-white drop-shadow-lg leading-tight">{event.title}</h1>

        {/* Date/Time */}
        {displayOption && (
          <div className="flex items-center gap-1.5">
            <CalendarDays className="w-3 h-3 text-accent" />
            {isUrgent ? (
              <div className="flex items-center gap-1.5">
                <span className="text-[11px] font-extrabold text-white bg-accent px-2 py-0.5 rounded">
                  {relativeDay.toUpperCase()}
                </span>
                <span className="text-xs font-bold text-muted-foreground">·</span>
                <span className="text-sm font-extrabold text-accent">{formatTime(displayOption.start_time)}</span>
              </div>
            ) : (
              <span className="text-sm text-white/90">
                {formatDate(displayOption.start_time)} · <span className="font-extrabold text-accent">{formatTime(displayOption.start_time)}</span>
              </span>
            )}
          </div>
        )}

        {/* Location — clickable when map link available */}
        {locationPres && (
          <div className="relative">
            {locationPres.googleMapsURL ? (
              <button
                onClick={() => setShowMapMenu(prev => !prev)}
                className="flex items-center gap-1.5 group text-left"
              >
                <MapPin className="w-3 h-3 text-muted-foreground flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-sm font-medium text-white/90 truncate block group-hover:text-primary transition-colors">
                    {locationPres.title}
                  </span>
                  {locationPres.subtitle && (
                    <span className="text-[11px] text-white/60 truncate block">
                      {locationPres.subtitle}
                    </span>
                  )}
                </div>
                <ExternalLink className="w-2.5 h-2.5 text-white/40 flex-shrink-0" />
              </button>
            ) : (
              <div className="flex items-center gap-1.5">
                <MapPin className="w-3 h-3 text-muted-foreground flex-shrink-0" />
                <div className="min-w-0">
                  <span className="text-sm font-medium text-white/90 truncate block">
                    {locationPres.title}
                  </span>
                  {locationPres.subtitle && (
                    <span className="text-[11px] text-white/60 truncate block">
                      {locationPres.subtitle}
                    </span>
                  )}
                </div>
              </div>
            )}

            {/* Map picker dropdown */}
            {showMapMenu && locationPres.googleMapsURL && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setShowMapMenu(false)} />
                <div className="absolute bottom-full left-0 mb-2 bg-card border border-border rounded-lg shadow-lg z-50 py-1 min-w-[160px]">
                  {locationPres.appleMapsURL && (
                    <a
                      href={locationPres.appleMapsURL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block px-4 py-2 text-sm text-foreground hover:bg-muted transition-colors"
                      onClick={() => setShowMapMenu(false)}
                    >
                      Apple Maps
                    </a>
                  )}
                  <a
                    href={locationPres.googleMapsURL}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="block px-4 py-2 text-sm text-foreground hover:bg-muted transition-colors"
                    onClick={() => setShowMapMenu(false)}
                  >
                    Google Maps
                  </a>
                  {locationPres.wazeURL && (
                    <a
                      href={locationPres.wazeURL}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block px-4 py-2 text-sm text-foreground hover:bg-muted transition-colors"
                      onClick={() => setShowMapMenu(false)}
                    >
                      Waze
                    </a>
                  )}
                </div>
              </>
            )}
          </div>
        )}

        {/* Host */}
        {event.host && (
          <div className="flex items-center gap-1.5">
            <div className="w-[18px] h-[18px] rounded-full bg-muted flex items-center justify-center text-[10px] font-bold text-muted-foreground shrink-0 overflow-hidden">
              {event.host.avatar_url ? (
                <img src={event.host.avatar_url} alt="" className="w-full h-full object-cover" />
              ) : (
                event.host.display_name?.[0]?.toUpperCase() || "H"
              )}
            </div>
            <span className="text-xs text-white/70">Hosted by {event.host.display_name}</span>
          </div>
        )}

        {/* RSVP Row + Player Count Indicator */}
        {(rsvpStatusConfig || event.min_players > 0) && (
          <>
            <div className="border-t border-white/20 pt-2 mt-1 flex items-center justify-between">
              {rsvpStatusConfig && (
                <button onClick={onRSVPTap} disabled={!onRSVPTap} className="flex items-center gap-2 active:scale-95 transition-transform disabled:opacity-100">
                  <span className={rsvpStatusConfig.color}>{rsvpStatusConfig.icon}</span>
                  <span className={`text-sm font-semibold ${rsvpStatusConfig.isPending ? "text-primary" : "text-white"}`}>
                    {rsvpStatusConfig.label}
                  </span>
                  {!isCompleted && (rsvpStatusConfig.isPending ? (
                    <ChevronRight className="w-3 h-3 text-muted-foreground" />
                  ) : (
                    <Pencil className="w-3 h-3 text-muted-foreground" />
                  ))}
                </button>
              )}

              {event.min_players > 0 && (
                <div className="md:hidden">
                  <PlayerCountIndicator
                    confirmedCount={confirmedCount}
                    minPlayers={event.min_players}
                    maxPlayers={event.max_players}
                    size="standard"
                  />
                </div>
              )}
            </div>

            {event.rsvp_deadline && !isCompleted && new Date(event.rsvp_deadline) > new Date() && (
              <p className="text-[10px] font-extrabold text-muted-foreground tracking-wide">
                RSVP BY {new Date(event.rsvp_deadline).toLocaleDateString("en-US", { weekday: "long" }).toUpperCase()}
              </p>
            )}
          </>
        )}
      </div>
    </div>
  );
}
