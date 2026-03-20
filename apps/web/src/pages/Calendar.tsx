import { useState, useEffect, useMemo, useCallback } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { ListEventCard } from "@/components/ListEventCard";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import {
  ArrowLeft, Search, SlidersHorizontal, CalendarDays, List, X,
  Crown, CheckCircle2, HelpCircle, Clock, XCircle,
} from "lucide-react";
import {
  fetchUpcomingEvents, fetchMyInvites, fetchEventsByIds, fetchAcceptedInviteCounts,
} from "@/lib/queries";
import type { GameEvent, Invite } from "@/lib/types";
import { getEffectiveStartDate } from "@/lib/types";
import { format, startOfMonth, endOfMonth, startOfDay, addMonths, subMonths, eachDayOfInterval, getDay, isSameDay, isToday as isDateToday } from "date-fns";

// ─── Filter Categories (matching iOS CalendarViewModel.FilterCategory) ───
type FilterCategory = "my_events" | "attending" | "deciding" | "waiting" | "not_going";

const FILTER_DEFS: { id: FilterCategory; label: string; description: string; icon: React.ReactNode }[] = [
  { id: "my_events", label: "My Events", description: "Events you're hosting", icon: <Crown className="w-4 h-4" /> },
  { id: "attending", label: "Attending", description: "Accepted invitations", icon: <CheckCircle2 className="w-4 h-4" /> },
  { id: "deciding", label: "Deciding", description: "Pending or maybe responses", icon: <HelpCircle className="w-4 h-4" /> },
  { id: "waiting", label: "Waiting on Host", description: "Waitlisted invitations", icon: <Clock className="w-4 h-4" /> },
  { id: "not_going", label: "Not Going", description: "Declined or expired", icon: <XCircle className="w-4 h-4" /> },
];

const DEFAULT_FILTERS = new Set<FilterCategory>(["my_events", "attending", "deciding", "waiting"]);

export default function Calendar() {
  const { user, loading: authLoading } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const initialView = searchParams.get("view") === "list" ? "list" : "calendar";

  const [viewMode, setViewMode] = useState<"calendar" | "list">(initialView);
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(new Date());
  const [searchQuery, setSearchQuery] = useState("");
  const [showSearch, setShowSearch] = useState(false);
  const [showFilter, setShowFilter] = useState(false);
  const [activeFilters, setActiveFilters] = useState<Set<FilterCategory>>(new Set(DEFAULT_FILTERS));

  const [allEvents, setAllEvents] = useState<GameEvent[]>([]);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [inviteCounts, setInviteCounts] = useState<Record<string, number>>({});
  const [isLoading, setIsLoading] = useState(true);

  const currentUserId = user?.id;

  const loadData = useCallback(async () => {
    if (!currentUserId) return;
    try {
      const [eventsRes, invitesRes] = await Promise.allSettled([
        fetchUpcomingEvents(currentUserId),
        fetchMyInvites(currentUserId),
      ]);
      const events = eventsRes.status === "fulfilled" ? eventsRes.value : [];
      const invs = invitesRes.status === "fulfilled" ? invitesRes.value : [];

      // Fetch invite-linked events not already in the list
      const existingIds = new Set(events.map(e => e.id));
      const missingIds = [...new Set(invs.map(i => i.event_id))].filter(id => !existingIds.has(id));
      let merged = [...events];
      if (missingIds.length > 0) {
        try {
          const extra = await fetchEventsByIds(missingIds);
          const map = new Map<string, GameEvent>();
          for (const e of merged) map.set(e.id, e);
          for (const e of extra) map.set(e.id, e);
          merged = Array.from(map.values());
        } catch { /* non-fatal */ }
      }

      const allIds = merged.map(e => e.id);
      let counts: Record<string, number> = {};
      try { counts = await fetchAcceptedInviteCounts(allIds); } catch { /* non-fatal */ }

      merged.sort((a, b) => getEffectiveStartDate(a).getTime() - getEffectiveStartDate(b).getTime());
      setAllEvents(merged);
      setInvites(invs);
      setInviteCounts(counts);
    } catch { /* */ }
    setIsLoading(false);
  }, [currentUserId]);

  useEffect(() => {
    if (authLoading) return;
    if (!user) { navigate("/login"); return; }
    loadData();
  }, [authLoading, user, loadData, navigate]);

  // Helpers
  const inviteFor = useCallback((eventId: string) => invites.find(i => i.event_id === eventId) ?? null, [invites]);
  const confirmedCount = useCallback((eventId: string) => (inviteCounts[eventId] ?? 0) + 1, [inviteCounts]);

  // Filter logic (matching iOS CalendarViewModel.filteredEvents)
  const filteredEvents = useMemo(() => {
    let result = allEvents.filter(event => {
      const invite = inviteFor(event.id);
      const isHost = event.host_id === currentUserId;

      let matchesFilter = false;
      if (activeFilters.has("my_events") && isHost) matchesFilter = true;
      if (activeFilters.has("attending") && invite?.status === "accepted") matchesFilter = true;
      if (activeFilters.has("deciding") && (invite?.status === "pending" || invite?.status === "maybe")) matchesFilter = true;
      if (activeFilters.has("waiting") && invite?.status === "waitlisted") matchesFilter = true;
      if (activeFilters.has("not_going") && (invite?.status === "declined" || invite?.status === "expired")) matchesFilter = true;

      // If host with no invite, show under my_events
      if (!invite && !isHost) {
        // Public event with no invite — show if any filter is active
        if (activeFilters.has("attending") || activeFilters.has("my_events")) matchesFilter = true;
      }

      return matchesFilter;
    });

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(e =>
        e.title.toLowerCase().includes(q) ||
        e.host?.display_name?.toLowerCase().includes(q) ||
        e.games.some(g => g.game?.name?.toLowerCase().includes(q))
      );
    }

    return result;
  }, [allEvents, activeFilters, searchQuery, currentUserId, inviteFor]);

  // Calendar grid helpers
  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(currentMonth);
  const daysInMonth = eachDayOfInterval({ start: monthStart, end: monthEnd });
  const leadingBlanks = getDay(monthStart); // 0=Sun

  const eventsForDate = useCallback((date: Date) => {
    return filteredEvents.filter(e => isSameDay(getEffectiveStartDate(e), date));
  }, [filteredEvents]);

  // List mode: group by day
  const eventsByDay = useMemo(() => {
    const groups = new Map<string, { date: Date; events: GameEvent[] }>();
    for (const event of filteredEvents) {
      const d = startOfDay(getEffectiveStartDate(event));
      const key = d.toISOString();
      if (!groups.has(key)) groups.set(key, { date: d, events: [] });
      groups.get(key)!.events.push(event);
    }
    return Array.from(groups.values()).sort((a, b) => a.date.getTime() - b.date.getTime());
  }, [filteredEvents]);

  const todayIndex = useMemo(() => {
    const today = startOfDay(new Date());
    return eventsByDay.findIndex(g => g.date >= today);
  }, [eventsByDay]);

  // RSVP dot color for calendar grid
  const rsvpDotColor = useCallback((event: GameEvent): string => {
    if (event.host_id === currentUserId) return "bg-accent";
    const inv = inviteFor(event.id);
    if (!inv) return "bg-muted-foreground/40";
    switch (inv.status) {
      case "accepted": return "bg-primary";
      case "pending": return "bg-accent";
      case "maybe": return "bg-yellow-500";
      case "declined": return "bg-destructive/60";
      case "waitlisted": return "bg-muted-foreground/60";
      default: return "bg-muted-foreground/40";
    }
  }, [currentUserId, inviteFor]);

  const toggleFilter = (id: FilterCategory) => {
    setActiveFilters(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background pb-24 md:pb-0">
        <div className="max-w-3xl mx-auto px-5 pt-6 space-y-4">
          <Skeleton className="h-10 w-48" />
          <Skeleton className="h-[300px] rounded-xl" />
        </div>
      </div>
    );
  }

  const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

  return (
    <div className="min-h-screen bg-background pb-24 md:pb-0">
      <div className="max-w-3xl mx-auto">
        {/* ─── Header ─── */}
        <div className="flex items-center px-5 pt-5 pb-2">
          <button onClick={() => navigate(-1)} className="mr-3">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </button>
          <h1 className="text-2xl font-extrabold text-foreground tracking-tight">
            {format(currentMonth, "MMMM")}
          </h1>
          <span className="text-lg font-medium text-muted-foreground ml-1.5 mt-0.5">
            {format(currentMonth, "yyyy")}
          </span>
          <div className="flex-1" />
          <div className="flex items-center gap-1.5">
            <button
              onClick={() => { setShowSearch(s => !s); if (showSearch) setSearchQuery(""); }}
              className="w-9 h-9 rounded-full bg-card flex items-center justify-center border border-border/40 active:scale-95 transition-transform"
            >
              <Search className="w-4 h-4 text-muted-foreground" />
            </button>
            <button
              onClick={() => setShowFilter(true)}
              className="w-9 h-9 rounded-full bg-card flex items-center justify-center border border-border/40 active:scale-95 transition-transform"
            >
              <SlidersHorizontal className="w-4 h-4 text-muted-foreground" />
            </button>
            <button
              onClick={() => setCurrentMonth(new Date())}
              className="text-xs font-medium text-muted-foreground px-3 py-1.5 rounded-full bg-card border border-border/40 active:scale-95 transition-transform"
            >
              Today
            </button>
          </div>
        </div>

        {/* ─── Search Bar ─── */}
        {showSearch && (
          <div className="px-5 pb-2">
            <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-card border border-border/40">
              <Search className="w-4 h-4 text-muted-foreground shrink-0" />
              <Input
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                placeholder="Search events, games, hosts..."
                className="border-0 bg-transparent p-0 h-auto text-sm focus-visible:ring-0"
                autoFocus
              />
              {searchQuery && (
                <button onClick={() => setSearchQuery("")}>
                  <X className="w-4 h-4 text-muted-foreground" />
                </button>
              )}
            </div>
          </div>
        )}

        {/* ─── Content ─── */}
        {viewMode === "calendar" ? (
          <div
            className="px-5 pb-4"
            onTouchStart={e => { (e.currentTarget as any)._touchStartX = e.touches[0].clientX; }}
            onTouchEnd={e => {
              const startX = (e.currentTarget as any)._touchStartX;
              if (startX == null) return;
              const diff = e.changedTouches[0].clientX - startX;
              if (diff > 50) setCurrentMonth(prev => subMonths(prev, 1));
              else if (diff < -50) setCurrentMonth(prev => addMonths(prev, 1));
            }}
          >
            {/* Month nav arrows */}
            <div className="flex items-center justify-between mb-3">
              <button onClick={() => setCurrentMonth(prev => subMonths(prev, 1))} className="text-sm text-muted-foreground px-2 py-1 rounded-lg hover:bg-muted/50 active:scale-95 transition">
                ← {format(subMonths(currentMonth, 1), "MMM")}
              </button>
              <button onClick={() => setCurrentMonth(prev => addMonths(prev, 1))} className="text-sm text-muted-foreground px-2 py-1 rounded-lg hover:bg-muted/50 active:scale-95 transition">
                {format(addMonths(currentMonth, 1), "MMM")} →
              </button>
            </div>

            {/* Weekday headers */}
            <div className="grid grid-cols-7 gap-1 mb-1">
              {weekdays.map(d => (
                <div key={d} className="text-center text-[11px] font-medium text-muted-foreground py-1">{d}</div>
              ))}
            </div>

            {/* Day cells */}
            <div className="grid grid-cols-7 gap-1">
              {Array.from({ length: leadingBlanks }).map((_, i) => (
                <div key={`blank-${i}`} />
              ))}
              {daysInMonth.map(day => {
                const dayEvents = eventsForDate(day);
                const isSelected = selectedDate && isSameDay(day, selectedDate);
                const isToday = isDateToday(day);
                const hasEvents = dayEvents.length > 0;

                return (
                  <button
                    key={day.toISOString()}
                    onClick={() => setSelectedDate(prev => prev && isSameDay(prev, day) ? null : day)}
                    className={`relative flex flex-col items-center justify-center rounded-lg aspect-square transition-colors ${
                      isSelected
                        ? "bg-primary text-primary-foreground"
                        : isToday
                          ? "bg-primary/10 text-primary font-bold"
                          : "hover:bg-muted/50 text-foreground"
                    }`}
                  >
                    <span className={`text-[13px] tabular-nums ${isSelected ? "font-bold" : isToday ? "font-bold" : ""}`}>
                      {format(day, "d")}
                    </span>
                    {/* RSVP dots */}
                    {hasEvents && (
                      <div className="flex gap-[2px] mt-[2px]">
                        {dayEvents.slice(0, 3).map(ev => (
                          <div key={ev.id} className={`w-[5px] h-[5px] rounded-full ${isSelected ? "bg-primary-foreground/70" : rsvpDotColor(ev)}`} />
                        ))}
                      </div>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Selected day detail */}
            {selectedDate && (
              <div className="mt-4 space-y-2">
                <p className="text-sm font-medium text-muted-foreground">
                  {format(selectedDate, "EEEE · MMMM d")}
                </p>
                {eventsForDate(selectedDate).length === 0 ? (
                  <p className="text-sm text-muted-foreground/60 py-4 text-center">No events</p>
                ) : (
                  eventsForDate(selectedDate).map(event => (
                    <ListEventCard
                      key={event.id}
                      event={event}
                      myInvite={inviteFor(event.id)}
                      confirmedCount={confirmedCount(event.id)}
                      currentUserId={currentUserId}
                      onClick={() => navigate(`/events/${event.id}`)}
                    />
                  ))
                )}
              </div>
            )}
          </div>
        ) : (
          /* ─── List View ─── */
          <div className="px-5 pb-4 space-y-5">
            {eventsByDay.length === 0 ? (
              <div className="py-12 text-center">
                <CalendarDays className="w-8 h-8 text-muted-foreground/40 mx-auto mb-2" />
                <p className="text-sm text-muted-foreground">No events found</p>
              </div>
            ) : (
              eventsByDay.map((group, index) => {
                const isPast = group.date < startOfDay(new Date());
                return (
                  <div key={group.date.toISOString()}>
                    {/* Today divider */}
                    {index === todayIndex && todayIndex > 0 && (
                      <div className="flex items-center gap-3 mb-4">
                        <div className="flex-1 h-px bg-primary/30" />
                        <span className="text-xs font-semibold text-primary">Today</span>
                        <div className="flex-1 h-px bg-primary/30" />
                      </div>
                    )}
                    <div className={isPast ? "opacity-60" : ""}>
                      <h3 className="text-sm font-bold text-foreground mb-2">
                        {format(group.date, "EEEE, MMMM d")}
                      </h3>
                      <div className="space-y-2">
                        {group.events.map(event => (
                          <ListEventCard
                            key={event.id}
                            event={event}
                            myInvite={inviteFor(event.id)}
                            confirmedCount={confirmedCount(event.id)}
                            currentUserId={currentUserId}
                            onClick={() => navigate(`/events/${event.id}`)}
                          />
                        ))}
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}
      </div>

      {/* ─── View Mode Toggle (floating) ─── */}
      <div className="fixed bottom-28 md:bottom-8 right-5 flex bg-card rounded-xl border border-border/40 overflow-hidden"
        style={{ boxShadow: "0 4px 16px hsl(0 0% 0% / 0.12)" }}
      >
        <button
          onClick={() => setViewMode("calendar")}
          className={`w-11 h-11 flex items-center justify-center transition-colors ${
            viewMode === "calendar" ? "text-foreground" : "text-muted-foreground/50"
          }`}
        >
          <CalendarDays className="w-[18px] h-[18px]" />
        </button>
        <button
          onClick={() => setViewMode("list")}
          className={`w-11 h-11 flex items-center justify-center transition-colors ${
            viewMode === "list" ? "text-foreground" : "text-muted-foreground/50"
          }`}
        >
          <List className="w-[18px] h-[18px]" />
        </button>
      </div>

      {/* ─── Filter Dialog ─── */}
      <Dialog open={showFilter} onOpenChange={setShowFilter}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Filter Events</DialogTitle>
          </DialogHeader>
          <div className="space-y-1 py-2">
            {FILTER_DEFS.map(f => (
              <button
                key={f.id}
                onClick={() => toggleFilter(f.id)}
                className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg hover:bg-muted/40 transition-colors"
              >
                <div className="text-muted-foreground">{f.icon}</div>
                <div className="flex-1 text-left">
                  <p className="text-sm font-medium text-foreground">{f.label}</p>
                  <p className="text-xs text-muted-foreground">{f.description}</p>
                </div>
                <Checkbox checked={activeFilters.has(f.id)} />
              </button>
            ))}
          </div>
          <DialogFooter className="flex-row gap-2">
            <Button variant="ghost" size="sm" onClick={() => setActiveFilters(new Set(DEFAULT_FILTERS))}>
              Reset
            </Button>
            <DialogClose asChild>
              <Button size="sm">Done</Button>
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
