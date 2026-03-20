import { useEffect, useState, useMemo, useCallback, useRef } from "react";
import { useNavigate, Link } from "react-router-dom";
import { Plus } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { EventCard } from "@/components/EventCard";
import { ListEventCard } from "@/components/ListEventCard";
import { DraftCard } from "@/components/DraftCard";
import { EmptyState } from "@/components/EmptyState";
import { SectionHeader } from "@/components/SectionHeader";
import { Skeleton } from "@/components/ui/skeleton";
import { supabase } from "@/lib/supabase";
import meepleLogo from "@/assets/meeple_logo.png";
import {
  fetchUpcomingEvents,
  fetchMyInvites,
  fetchDrafts,
  fetchEventsByIds,
  fetchAcceptedInviteCounts,
} from "@/lib/queries";
import type { GameEvent, Invite } from "@/lib/types";
import { getEffectiveStartDate } from "@/lib/types";

export default function Dashboard() {
  const { user, loading: authLoading } = useAuth();
  const navigate = useNavigate();

  const [upcomingEvents, setUpcomingEvents] = useState<GameEvent[]>([]);
  const [myInvites, setMyInvites] = useState<Invite[]>([]);
  const [drafts, setDrafts] = useState<GameEvent[]>([]);
  const [inviteCounts, setInviteCounts] = useState<Record<string, number>>({});
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const currentUserId = user?.id;

  const loadData = useCallback(async () => {
    if (!currentUserId) return;

    setError(null);
    try {
      const [eventsResult, invitesResult, draftsResult] = await Promise.allSettled([
        fetchUpcomingEvents(currentUserId),
        fetchMyInvites(currentUserId),
        fetchDrafts(currentUserId),
      ]);

      const events = eventsResult.status === "fulfilled" ? eventsResult.value : [];
      const invites = invitesResult.status === "fulfilled" ? invitesResult.value : [];
      const draftsList = draftsResult.status === "fulfilled" ? draftsResult.value : [];

      const inviteLinkedEventIds = [...new Set(
        invites
          .filter(i => i.status === "pending" || i.status === "accepted" || i.status === "maybe" || i.status === "waitlisted")
          .map(i => i.event_id)
      )];

      let allEvents = [...events];
      const existingIds = new Set(allEvents.map(e => e.id));
      const missingIds = inviteLinkedEventIds.filter(id => !existingIds.has(id));

      if (missingIds.length > 0) {
        try {
          const inviteEvents = await fetchEventsByIds(missingIds);
          const merged = new Map<string, GameEvent>();
          for (const e of allEvents) merged.set(e.id, e);
          for (const e of inviteEvents) merged.set(e.id, e);
          allEvents = Array.from(merged.values());
        } catch { /* Non-fatal */ }
      }

      const allIds = allEvents.map(e => e.id);
      let counts: Record<string, number> = {};
      try { counts = await fetchAcceptedInviteCounts(allIds); } catch { /* Non-fatal */ }

      allEvents.sort((a, b) => getEffectiveStartDate(a).getTime() - getEffectiveStartDate(b).getTime());
      setUpcomingEvents(allEvents);
      setMyInvites(invites);
      setDrafts(draftsList);
      setInviteCounts(counts);
    } catch (err) {
      setError((err as Error).message ?? "Unknown error");
    }
    setIsLoading(false);
  }, [currentUserId]);

  useEffect(() => {
    if (authLoading) return;
    if (!user) { navigate("/login"); return; }
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authLoading]);

  const awaitingResponseEvents = useMemo(() => {
    const pending = myInvites.filter(i => i.status === "pending");
    return pending
      .map(invite => {
        const event = upcomingEvents.find(e => e.id === invite.event_id);
        return event ? { event, invite } : null;
      })
      .filter(Boolean) as { event: GameEvent; invite: Invite }[];
  }, [myInvites, upcomingEvents]);

  const startOfToday = useMemo(() => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; }, []);
  const futureEvents = useMemo(() => upcomingEvents.filter(e => getEffectiveStartDate(e) >= startOfToday), [upcomingEvents, startOfToday]);
  const hostingEvents = useMemo(() => futureEvents.filter(e => e.host_id === currentUserId), [futureEvents, currentUserId]);

  const confirmedCount = (eventId: string) => (inviteCounts[eventId] ?? 0) + 1;
  const inviteFor = (eventId: string) => myInvites.find(i => i.event_id === eventId) ?? null;
  const isEmpty = awaitingResponseEvents.length === 0 && futureEvents.length === 0 && drafts.length === 0;

  /* ─── MOBILE LAYOUT ─── */
  const mobileContent = (
    <div className="md:hidden min-h-screen bg-background flex flex-col">
      <div className="flex-1 pb-28">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-6 pb-1">
          <div>
            <div className="flex items-center gap-1.5">
              <h1 className="text-[1.7rem] font-extrabold tracking-tight text-foreground leading-none">
                Game Night
              </h1>
              <img src={meepleLogo} alt="" className="w-6 h-6 opacity-60" />
            </div>
            <p className="text-[13px] text-muted-foreground mt-0.5">Your upcoming sessions</p>
          </div>
          <button
            onClick={() => navigate("/events/new")}
            className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center active:scale-95 transition-transform"
            style={{ boxShadow: "0 2px 8px hsl(94 19% 48% / 0.3)" }}
          >
            <Plus className="w-5 h-5" strokeWidth={2.5} />
          </button>
        </div>

        {error && <ErrorBanner onRetry={loadData} />}

        <div className="mt-5 space-y-6">
          {drafts.length > 0 && (
            <section className="space-y-2.5">
              <div className="px-5"><SectionHeader title="Drafts" /></div>
              <div className="flex gap-3 overflow-x-auto px-5 pb-1 scrollbar-hide">
                {drafts.map(draft => (
                  <DraftCard key={draft.id} draft={draft} onClick={() => navigate(`/events/${draft.id}`)} />
                ))}
              </div>
            </section>
          )}

          {isLoading ? (
            <div className="px-5 space-y-4">
              {[1, 2].map(i => <Skeleton key={i} className="h-[220px] rounded-[14px]" />)}
            </div>
          ) : isEmpty ? (
            <EmptyState onCreateEvent={() => navigate("/events/new")} />
          ) : (
            <>
              {awaitingResponseEvents.length > 0 && (
                <section className="space-y-2.5">
                  <div className="px-5"><SectionHeader title="Awaiting Response" /></div>
                  <CardCarousel>
                    {awaitingResponseEvents.map(({ event, invite }) => (
                      <CarouselCard key={event.id}>
                        <EventCard event={event} myInvite={invite} confirmedCount={confirmedCount(event.id)} currentUserId={currentUserId} onClick={() => navigate(`/events/${event.id}`)} />
                      </CarouselCard>
                    ))}
                  </CardCarousel>
                </section>
              )}
              {futureEvents.length > 0 && (
                <section className="space-y-2.5">
                  <div className="px-5"><SectionHeader title="Next Up" action="View all" onAction={() => navigate("/calendar")} /></div>
                  <CardCarousel>
                    {futureEvents.map(event => (
                      <CarouselCard key={event.id}>
                        <EventCard event={event} myInvite={inviteFor(event.id)} confirmedCount={confirmedCount(event.id)} currentUserId={currentUserId} onClick={() => navigate(`/events/${event.id}`)} />
                      </CarouselCard>
                    ))}
                  </CardCarousel>
                </section>
              )}
              {hostingEvents.length > 0 && (
                <section className="space-y-2.5">
                  <div className="px-5"><SectionHeader title="Hosting" /></div>
                  <CardCarousel>
                    {hostingEvents.map(event => (
                      <CarouselCard key={event.id}>
                        <EventCard event={event} myInvite={inviteFor(event.id)} confirmedCount={confirmedCount(event.id)} currentUserId={currentUserId} onClick={() => navigate(`/events/${event.id}`)} />
                      </CarouselCard>
                    ))}
                  </CardCarousel>
                </section>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );

  /* ─── DESKTOP LAYOUT ─── */
  const allSections = [
    ...(awaitingResponseEvents.length > 0 ? [{ title: "Awaiting Response", events: awaitingResponseEvents.map(a => a.event), getInvite: (id: string) => awaitingResponseEvents.find(a => a.event.id === id)?.invite ?? null }] : []),
    ...(futureEvents.length > 0 ? [{ title: "Next Up", events: futureEvents, getInvite: inviteFor, action: "View all" }] : []),
    ...(hostingEvents.length > 0 ? [{ title: "Hosting", events: hostingEvents, getInvite: inviteFor }] : []),
  ];

  const totalEvents = futureEvents.length;
  const totalHosting = hostingEvents.length;
  const totalPending = awaitingResponseEvents.length;

  const desktopContent = (
    <div className="hidden md:block min-h-screen bg-background">
      <div className="flex">
        {/* Events column */}
        <div className="flex-1 min-w-0 px-6 lg:px-8 py-8 space-y-8">
          <div>
            <h2 className="text-2xl font-extrabold text-foreground">Your Sessions</h2>
            <p className="text-sm text-muted-foreground mt-0.5">Upcoming game nights and invites</p>
          </div>

          {error && <ErrorBanner onRetry={loadData} />}

          {drafts.length > 0 && (
            <section className="space-y-3">
              <SectionHeader title="Drafts" />
              <DesktopScrollRow>
                {drafts.map(draft => (
                  <DraftCard key={draft.id} draft={draft} onClick={() => navigate(`/events/${draft.id}`)} />
                ))}
              </DesktopScrollRow>
            </section>
          )}

          {isLoading ? (
            <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
              {[1, 2, 3].map(i => <Skeleton key={i} className="h-[244px] rounded-[14px]" />)}
            </div>
          ) : isEmpty ? (
            <EmptyState onCreateEvent={() => navigate("/events/new")} />
          ) : (
            <>
              {allSections.map(section => (
                <section key={section.title} className="space-y-3">
                  <SectionHeader title={section.title} action={(section as any).action} onAction={(section as any).action ? () => navigate("/calendar") : undefined} />
                  <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
                    {section.events.map(event => (
                      <EventCard
                        key={event.id}
                        event={event}
                        myInvite={section.getInvite(event.id)}
                        confirmedCount={confirmedCount(event.id)}
                        currentUserId={currentUserId}
                        onClick={() => navigate(`/events/${event.id}`)}
                      />
                    ))}
                  </div>
                </section>
              ))}
            </>
          )}
        </div>

        {/* Right sidebar — quick glance */}
        <aside className="hidden lg:block w-[220px] xl:w-[260px] shrink-0 border-l border-border/40 sticky top-0 h-screen overflow-y-auto py-8 px-5">
          <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-4">Quick Glance</h3>
          <div className="space-y-3">
            <GlanceCard label="Upcoming" value={totalEvents} color="text-primary" />
            <GlanceCard label="Hosting" value={totalHosting} color="text-accent" />
            <GlanceCard label="Pending" value={totalPending} color="text-muted-foreground" />
          </div>

          {futureEvents.length > 0 && (
            <div className="mt-6">
              <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">Coming Soon</h3>
              <div className="space-y-2">
                {futureEvents.slice(0, 4).map(event => {
                  const d = getEffectiveStartDate(event);
                  return (
                    <button
                      key={event.id}
                      onClick={() => navigate(`/events/${event.id}`)}
                      className="w-full text-left p-2.5 rounded-lg bg-card hover:bg-muted/40 transition-colors border border-border/30"
                    >
                      <p className="text-[11px] font-semibold text-accent tabular-nums">
                        {d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}
                      </p>
                      <p className="text-[13px] font-bold text-foreground truncate mt-0.5">{event.title}</p>
                    </button>
                  );
                })}
              </div>
            </div>
          )}
        </aside>
      </div>
    </div>
  );

  return (
    <>
      {mobileContent}
      {desktopContent}
    </>
  );
}

/* ─── Shared sub-components ─── */

function ErrorBanner({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="mx-5 md:mx-0 mt-3 p-3 rounded-lg bg-destructive/10 border border-destructive/20">
      <p className="text-sm font-medium text-destructive">Some data couldn't load</p>
      <button onClick={onRetry} className="text-xs text-primary font-medium mt-1">Try Again</button>
    </div>
  );
}



/** Hook: mouse-drag horizontal scrolling for desktop */
function useDragScroll() {
  const ref = useRef<HTMLDivElement>(null);
  const state = useRef({ isDown: false, startX: 0, scrollLeft: 0, moved: false });

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    const el = ref.current;
    if (!el) return;
    state.current = { isDown: true, startX: e.pageX - el.offsetLeft, scrollLeft: el.scrollLeft, moved: false };
    el.style.cursor = "grabbing";
    el.style.userSelect = "none";
  }, []);

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (!state.current.isDown) return;
    e.preventDefault();
    const el = ref.current!;
    const x = e.pageX - el.offsetLeft;
    const walk = (x - state.current.startX) * 1.2;
    if (Math.abs(walk) > 3) state.current.moved = true;
    el.scrollLeft = Math.max(0, state.current.scrollLeft - walk);
  }, []);

  const onMouseUpOrLeave = useCallback(() => {
    state.current.isDown = false;
    const el = ref.current;
    if (el) { el.style.cursor = "grab"; el.style.removeProperty("user-select"); }
  }, []);

  return { ref, onMouseDown, onMouseMove, onMouseUp: onMouseUpOrLeave, onMouseLeave: onMouseUpOrLeave };
}

function CardCarousel({ children }: { children: React.ReactNode }) {
  const drag = useDragScroll();
  return (
    <div
      ref={drag.ref}
      className="flex gap-3 overflow-x-auto pl-5 pr-5 pb-1 scrollbar-hide snap-x snap-mandatory cursor-grab"
      style={{ WebkitOverflowScrolling: "touch", overscrollBehaviorX: "contain", scrollPaddingLeft: "1.25rem" }}
      onMouseDown={drag.onMouseDown}
      onMouseMove={drag.onMouseMove}
      onMouseUp={drag.onMouseUp}
      onMouseLeave={drag.onMouseLeave}
    >
      {children}
    </div>
  );
}

function CarouselCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="shrink-0 snap-start" style={{ width: "calc((100vw - 48px) / 2.05)" }}>
      {children}
    </div>
  );
}

function DesktopScrollRow({ children }: { children: React.ReactNode }) {
  const drag = useDragScroll();
  return (
    <div
      ref={drag.ref}
      className="flex gap-3 overflow-x-auto scrollbar-hide pb-1 cursor-grab snap-x"
      style={{ overscrollBehaviorX: "contain" }}
      onMouseDown={drag.onMouseDown}
      onMouseMove={drag.onMouseMove}
      onMouseUp={drag.onMouseUp}
      onMouseLeave={drag.onMouseLeave}
    >
      {children}
    </div>
  );
}

function GlanceCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="p-3 rounded-xl bg-card border border-border/30">
      <p className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">{label}</p>
      <p className={`text-2xl font-extrabold tabular-nums mt-0.5 ${color}`}>{value}</p>
    </div>
  );
}
