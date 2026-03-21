import { useParams, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase.ts";
import { useAuth } from "@/contexts/AuthContext.tsx";
import { Button } from "@/components/ui/button.tsx";
import { Card, CardContent } from "@/components/ui/card.tsx";
import { Skeleton } from "@/components/ui/skeleton.tsx";
import {
  Dice5,
  MapPin,
  Calendar,
  Clock,
  Users,
  Check,
  Smartphone,
  ChevronRight,
  Download,
} from "lucide-react";
import { format, parseISO } from "date-fns";

interface PublicInviteData {
  id: string;
  display_name: string | null;
  status: string;
  is_active: boolean;
  created_at: string;
  rsvp_requires_auth: boolean;
  event: {
    id: string;
    title: string;
    description: string | null;
    location: string | null;
    location_address: string | null;
    allow_time_suggestions: boolean;
    host: { display_name: string } | null;
    games: Array<{
      is_primary: boolean;
      sort_order: number;
      game: {
        name: string;
        complexity: number;
        min_playtime: number;
        max_playtime: number;
        min_players: number;
        max_players: number;
        thumbnail_url: string | null;
      } | null;
    }>;
    time_options: Array<{
      id: string;
      date: string;
      start_time: string;
      end_time: string | null;
      label: string | null;
      vote_count: number;
    }>;
  };
}

export default function InvitePreview() {
  const { token } = useParams<{ token: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [invite, setInvite] = useState<PublicInviteData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedTimeId, setSelectedTimeId] = useState<string | null>(null);

  useEffect(() => {
    if (!token) return;
    (async () => {
      setLoading(true);
      try {
        const { data, error: fnErr } = await supabase.functions.invoke(
          "get-public-invite",
          { body: { invite_token: token } }
        );
        if (fnErr || data?.error) throw new Error(data?.error ?? fnErr?.message ?? "Failed to load invite");
        setInvite(data as PublicInviteData);
      } catch (e: unknown) {
        setError(e instanceof Error ? e.message : "Something went wrong");
      } finally {
        setLoading(false);
      }
    })();
  }, [token]);

  const handleRSVP = (rsvpStatus: "accepted" | "maybe" | "declined") => {
    if (!invite) return;
    const eventId = invite.event.id;
    // Store selections so they can be applied after login
    localStorage.setItem("pendingRSVP", JSON.stringify({
      eventId,
      inviteToken: token,
      status: rsvpStatus,
      selectedTimeId,
    }));
    if (user) {
      navigate(`/events/${eventId}`);
    } else {
      navigate(`/login?returnTo=/events/${eventId}&inviteToken=${token}`);
    }
  };

  const deepLink = `gamenight://invite/${token}`;

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4">
        <div className="w-full max-w-md space-y-4">
          <Skeleton className="h-8 w-3/4 mx-auto" />
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-32 w-full rounded-xl" />
          <Skeleton className="h-12 w-full rounded-xl" />
        </div>
      </div>
    );
  }

  if (error || !invite) {
    return (
      <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4 text-center gap-4">
        <Dice5 className="h-12 w-12 text-muted-foreground" />
        <h1 className="text-xl font-bold text-foreground">Invite Not Found</h1>
        <p className="text-muted-foreground text-sm max-w-xs">
          {error ?? "This invite link may have expired or is no longer valid."}
        </p>
        <Button variant="outline" onClick={() => navigate("/")}>
          Go Home
        </Button>
      </div>
    );
  }

  const { event } = invite;
  const hostName = event.host?.display_name ?? "Someone";
  const sortedGames = [...event.games].sort((a, b) => {
    if (a.is_primary && !b.is_primary) return -1;
    if (!a.is_primary && b.is_primary) return 1;
    return (a.sort_order ?? 0) - (b.sort_order ?? 0);
  });
  const sortedTimes = [...event.time_options].sort(
    (a, b) => new Date(a.start_time).getTime() - new Date(b.start_time).getTime()
  );

  return (
    <div className="min-h-screen bg-background">
      {/* Hero */}
      <div className="relative bg-gradient-to-b from-primary/15 to-background px-6 pt-12 pb-8 text-center border-b border-border">
        <div className="flex items-center justify-center mb-5">
          <div className="w-16 h-16 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center">
            <Dice5 className="h-8 w-8 text-primary" />
          </div>
        </div>
        <h1 className="text-2xl md:text-3xl font-bold text-foreground mb-2 tracking-tight">
          {event.title}
        </h1>
        <p className="text-muted-foreground text-sm">
          Hosted by <span className="font-medium text-foreground">{hostName}</span>
        </p>
      </div>

      <div className="max-w-md mx-auto px-4 pt-6 space-y-4 pb-10">
        {/* Games */}
        {sortedGames.length > 0 && (
          <Card>
            <CardContent className="p-4 space-y-1">
              <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5 mb-3">
                <Dice5 className="h-3.5 w-3.5" /> Games
              </h2>
              {sortedGames.map((eg, i) => {
                const g = eg.game;
                if (!g) return null;
                return (
                  <div key={i} className="flex items-center gap-4 py-3 border-b border-border/50 last:border-b-0">
                    {g.thumbnail_url ? (
                      <img
                        src={g.thumbnail_url}
                        alt={g.name}
                        className="w-14 h-14 rounded-lg object-cover bg-muted border border-border"
                      />
                    ) : (
                      <div className="w-14 h-14 rounded-lg bg-muted border border-border flex items-center justify-center">
                        <Dice5 className="h-6 w-6 text-muted-foreground" />
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm text-foreground truncate flex items-center gap-1.5">
                        {g.name}
                        {eg.is_primary && (
                          <span className="text-[10px] bg-primary/15 text-primary font-semibold px-1.5 py-0.5 rounded-full">
                            Main
                          </span>
                        )}
                      </p>
                      <p className="text-xs text-muted-foreground mt-1 flex items-center gap-2 flex-wrap">
                        <span>{g.min_players}–{g.max_players} players</span>
                        <span>·</span>
                        <span>{g.min_playtime}–{g.max_playtime} min</span>
                      </p>
                    </div>
                    <ComplexityDots value={g.complexity} />
                  </div>
                );
              })}
            </CardContent>
          </Card>
        )}

        {/* Time Options — Selectable */}
        {sortedTimes.length > 0 && (
          <Card>
            <CardContent className="p-4 space-y-3">
              <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5 mb-1">
                <Calendar className="h-3.5 w-3.5" /> When
              </h2>
              {sortedTimes.map((t) => {
                const isSelected = selectedTimeId === t.id;
                return (
                  <button
                    key={t.id}
                    onClick={() => setSelectedTimeId(isSelected ? null : t.id)}
                    className={`w-full flex items-center gap-4 p-4 rounded-xl border transition-all text-left ${
                      isSelected
                        ? "border-primary bg-primary/10 shadow-[0_0_0_1px_hsl(var(--primary))]"
                        : "border-border bg-muted/30 hover:bg-muted/60 hover:border-muted-foreground/30"
                    }`}
                  >
                    {/* Radio */}
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                        isSelected
                          ? "border-primary bg-primary"
                          : "border-muted-foreground/40"
                      }`}
                    >
                      {isSelected && (
                        <div className="w-2 h-2 rounded-full bg-primary-foreground" />
                      )}
                    </div>
                    <div className="flex-1">
                      <p className="text-sm font-semibold text-foreground flex items-center gap-2">
                        {format(parseISO(t.start_time), "EEE, MMM d")}
                        {t.label && (
                          <span className="text-[11px] font-semibold text-primary bg-primary/15 px-2 py-0.5 rounded-md uppercase">
                            {t.label}
                          </span>
                        )}
                      </p>
                      <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                        <Clock className="h-3 w-3" />
                        {format(parseISO(t.start_time), "h:mm a")}
                        {t.end_time && ` – ${format(parseISO(t.end_time), "h:mm a")}`}
                      </p>
                    </div>
                    {t.vote_count > 0 && (
                      <span className="text-xs font-medium text-accent bg-accent/10 px-2 py-1 rounded-md">
                        {t.vote_count} vote{t.vote_count !== 1 ? "s" : ""}
                      </span>
                    )}
                  </button>
                );
              })}
            </CardContent>
          </Card>
        )}

        {/* Location */}
        {event.location && (
          <Card>
            <CardContent className="p-4">
              <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5 mb-3">
                <MapPin className="h-3.5 w-3.5" /> Location
              </h2>
              <div className="flex items-center gap-4">
                <div className="w-11 h-11 rounded-xl bg-muted border border-border flex items-center justify-center flex-shrink-0">
                  <MapPin className="h-5 w-5 text-muted-foreground" />
                </div>
                <div>
                  <p className="text-sm font-semibold text-foreground">{event.location}</p>
                  {event.location_address && (
                    <p className="text-xs text-muted-foreground mt-0.5">
                      Full address available after RSVP
                    </p>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Description */}
        {event.description && (
          <Card>
            <CardContent className="p-4">
              <p className="text-sm text-foreground/90 whitespace-pre-wrap leading-relaxed">
                {event.description}
              </p>
            </CardContent>
          </Card>
        )}

        {/* RSVP Buttons */}
        <div className="space-y-3 pt-2">
          <Button
            className="w-full h-12 text-base font-semibold"
            onClick={() => handleRSVP("accepted")}
          >
            <Check className="h-5 w-5 mr-2" />
            I'm Going
          </Button>
          <div className="flex gap-3">
            <Button
              variant="outline"
              className="flex-1 h-12 font-semibold"
              onClick={() => handleRSVP("maybe")}
            >
              Maybe
            </Button>
            <Button
              variant="outline"
              className="flex-1 h-12 font-semibold text-muted-foreground hover:text-destructive hover:border-destructive/50"
              onClick={() => handleRSVP("declined")}
            >
              Can't Make It
            </Button>
          </div>
        </div>

        {/* App Banner */}
        <div className="mt-6 rounded-xl border border-border bg-card overflow-hidden">
          {/* Open in App row */}
          <a
            href={deepLink}
            className="flex items-center gap-3 p-4 hover:bg-muted/60 transition-colors"
          >
            <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-primary/20 to-accent/10 border border-primary/20 flex items-center justify-center flex-shrink-0">
              <Dice5 className="h-6 w-6 text-primary" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-foreground">CardboardWithMe</p>
              <p className="text-xs text-muted-foreground">Open this invite in the app</p>
            </div>
            <span className="text-xs font-semibold text-primary bg-primary/10 px-3 py-1.5 rounded-lg flex-shrink-0">
              Open
            </span>
          </a>

          <div className="border-t border-border" />

          {/* App Store download */}
          <a
            href="https://apps.apple.com/app/cardboardwithme/id6744382591"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 p-4 hover:bg-muted/60 transition-colors"
          >
            <div className="w-12 h-12 rounded-xl bg-muted border border-border flex items-center justify-center flex-shrink-0">
              <svg viewBox="0 0 24 24" className="w-6 h-6 text-foreground" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-[10px] text-muted-foreground uppercase tracking-wide font-medium">Download on the</p>
              <p className="text-sm font-semibold text-foreground -mt-0.5">App Store</p>
            </div>
            <ChevronRight className="h-4 w-4 text-muted-foreground flex-shrink-0" />
          </a>
        </div>
      </div>
    </div>
  );
}

function ComplexityDots({ value }: { value: number }) {
  const filled = Math.round(value);
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((i) => (
        <div
          key={i}
          className={`w-1.5 h-1.5 rounded-full ${
            i <= filled ? "bg-accent" : "bg-border"
          }`}
        />
      ))}
    </div>
  );
}
