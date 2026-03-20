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
    setError(null);
    try {
      const [eventsResult, invitesResult, draftsResult] = await Promise.allSettled([
        fetchUpcomingEvents(),
        fetchMyInvites(),
        fetchDrafts(),
      ]);

      const events = eventsResult.status === "fulfilled" ? eventsResult.value : [];
      const invites = invitesResult.status === "fulfilled" ? invitesResult.value : [];
      const draftsList = draftsResult.status === "fulfilled" ? draftsResult.value : [];

      const acceptedInviteEventIds = invites
        .filter(i => i.status === "accepted" || i.status === "maybe")
        .map(i => i.event_id);
      const existingIds = new Set(events.map(e => e.id));
      const missingIds = acceptedInviteEventIds.filter(id => !existingIds.has(id));

      let allEvents = [...events];
      if (missingIds.length > 0) {
        try {
          const inviteEvents = await fetchEventsByIds(missingIds);
          const merged = new Map<string, GameEvent>();
          for (const e of allEvents) merged.set(e.id, e);
          for (const e of inviteEvents) merged.set(e.id, e);
          allEvents = Array.from(merged.values());
        } catch { /* Non-fatal */ }
      }

      const pendingInvites = invites.filter(i => i.status === "pending");
      if (pendingInvites.length > 0) {
        const pendingIds = [...new Set(pendingInvites.map(i => i.event_id))].filter(id => !existingIds.has(id));
        if (pendingIds.length > 0) {
          try {
            const pendingEvents = await fetchEventsByIds(pendingIds);
            const merged = new Map<string, GameEvent>();
            for (const ev of allEvents) merged.set(ev.id, ev);
            for (const e of pendingEvents) merged.set(e.id, e);
            allEvents = Array.from(merged.values());
          } catch { /* Non-fatal */ }
        }
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
  }, []);

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
                  <div className="px-5"><SectionHeader title="Next Up" action="View all" onAction={() => {}} /></div>
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
    <div className="hidden md:flex min-h-screen bg-background">
      {/* Sidebar */}
      <aside className="w-[220px] lg:w-[240px] shrink-0 border-r border-border/60 flex flex-col sticky top-0 h-screen"
        style={{ background: "hsl(var(--card))" }}
      >
        <div className="px-5 pt-6 pb-4">
          <div className="flex items-center gap-1.5">
            <h1 className="text-[15px] lg:text-base font-extrabold tracking-tight text-foreground leading-none whitespace-nowrap">
              CardboardWithMe
            </h1>
            <img src={meepleLogo} alt="" className="w-5 h-5 opacity-60" />
          </div>
        </div>

        <nav className="flex-1 px-3 space-y-1">
          <SidebarLink label="Home" active icon={<IconHome />} href="/dashboard" />
          <SidebarLink label="Games" icon={<IconDice />} href="/dashboard" />
          <SidebarLink label="Groups" icon={<IconGroups />} href="/dashboard" />
          <SidebarLink label="Profile" icon={<IconProfile />} href="/profile" />
        </nav>

        <div className="p-3">
          <button
            onClick={() => navigate("/events/new")}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary text-primary-foreground font-semibold text-sm active:scale-[0.97] transition-transform"
            style={{ boxShadow: "0 2px 8px hsl(94 19% 48% / 0.3)" }}
          >
            <Plus className="w-4 h-4" strokeWidth={2.5} />
            New Event
          </button>
        </div>
      </aside>

      {/* Main content — grid of vertical cards */}
      <main className="flex-1 min-w-0 overflow-y-auto">
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
                    <SectionHeader title={section.title} action={(section as any).action} onAction={(section as any).action ? () => {} : undefined} />
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
      </main>
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

function SidebarLink({ label, icon, href, active }: { label: string; icon: React.ReactNode; href: string; active?: boolean }) {
  return (
    <Link
      to={href}
      className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors ${
        active
          ? "bg-primary/10 text-primary"
          : "text-muted-foreground hover:bg-muted/60 hover:text-foreground"
      }`}
    >
      <span className="w-5 h-5 flex items-center justify-center">{icon}</span>
      {label}
    </Link>
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
    el.scrollLeft = state.current.scrollLeft - walk;
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
      className="flex gap-3 overflow-x-auto px-5 pb-1 scrollbar-hide snap-x snap-mandatory cursor-grab"
      style={{ WebkitOverflowScrolling: "touch", overscrollBehaviorX: "contain" }}
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

/* ─── SVG Icons (filled, matching iOS SF Symbols) ─── */
function IconHome() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 3l9 8h-3v9h-5v-6h-2v6H6v-9H3l9-8z"/></svg>;
}
function IconDice() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M2 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2V4zm3 1a1 1 0 100 2 1 1 0 000-2zm3 3a1 1 0 100 2 1 1 0 000-2zM13 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2V4zm4.5.5a1 1 0 100 2 1 1 0 000-2zm-2 2a1 1 0 100 2 1 1 0 000-2zm2 2a1 1 0 100 2 1 1 0 000-2zM2 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2v-5zm3.5.5a1 1 0 100 2 1 1 0 000-2zm0 3a1 1 0 100 2 1 1 0 000-2zm-2-3a1 1 0 100 2 1 1 0 000-2zm4 3a1 1 0 100 2 1 1 0 000-2zM13 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2v-5zm2.5 2.5a2 2 0 104 0 2 2 0 00-4 0z"/></svg>;
}
function IconGroups() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 12.75c1.63 0 3.07.39 4.24.9 1.08.48 1.76 1.56 1.76 2.73V18H6v-1.61c0-1.18.68-2.26 1.76-2.73 1.17-.52 2.61-.91 4.24-.91zM4 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm1.13 1.1C4.76 14.04 4.39 14 4 14c-.99 0-1.93.21-2.78.58A2.01 2.01 0 000 16.43V18h4.5v-1.61c0-.83.23-1.61.63-2.29zM20 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm4 3.43c0-.81-.48-1.53-1.22-1.85A6.95 6.95 0 0020 14c-.39 0-.76.04-1.13.1.4.68.63 1.46.63 2.29V18H24v-1.57zM12 6c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z"/></svg>;
}
function IconProfile() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2a7.2 7.2 0 01-6-3.22c.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08a7.2 7.2 0 01-6 3.22z"/></svg>;
}
