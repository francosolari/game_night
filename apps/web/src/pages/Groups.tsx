import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Plus, Users, Gamepad2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { GroupBubble, NewGroupBubble } from "@/components/groups/GroupBubble";
import { CreateGroupDialog } from "@/components/groups/CreateGroupDialog";
import { RecentPlayRow } from "@/components/groups/RecentPlayRow";
import { EventCard } from "@/components/EventCard";
import { SectionHeader } from "@/components/SectionHeader";
import { fetchGroups, fetchEventsForGroup, fetchRecentPlaysAcrossGroups } from "@/lib/groupQueries";
import { fetchAcceptedInviteCounts } from "@/lib/queries";
import type { GameGroup } from "@/lib/groupTypes";
import type { Play } from "@/lib/groupTypes";
import type { GameEvent } from "@/lib/types";
import { useAuth } from "@/contexts/AuthContext";

export default function Groups() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const userId = user?.id;
  const [groups, setGroups] = useState<GameGroup[]>([]);
  const [upcomingEvents, setUpcomingEvents] = useState<GameEvent[]>([]);
  const [inviteCounts, setInviteCounts] = useState<Record<string, number>>({});
  const [recentPlays, setRecentPlays] = useState<Play[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const loadData = async () => {
    setLoading(true);
    try {
      const [grps, plays] = await Promise.all([
        fetchGroups(),
        fetchRecentPlaysAcrossGroups(),
      ]);
      setGroups(grps);
      setRecentPlays(plays);

      // Fetch upcoming events across groups
      const allEvents: GameEvent[] = [];
      for (const g of grps) {
        const events = await fetchEventsForGroup(g.id);
        const upcoming = events.filter(e =>
          (e.status === "published" || e.status === "confirmed") &&
          !e.deleted_at
        );
        allEvents.push(...upcoming);
      }
      // Deduplicate
      const unique = Array.from(new Map(allEvents.map(e => [e.id, e])).values());
      setUpcomingEvents(unique);

      if (unique.length > 0) {
        const counts = await fetchAcceptedInviteCounts(unique.map(e => e.id));
        setInviteCounts(counts);
      }
    } catch {
      // tables may not exist yet
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  const handleGroupCreated = (group: GameGroup) => {
    setGroups(prev => [group, ...prev]);
  };

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-6 space-y-6 pb-24">
        <Skeleton className="h-8 w-32" />
        <div className="flex gap-3">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="w-[72px] h-20 rounded-2xl" />)}
        </div>
        <Skeleton className="h-48 rounded-xl" />
      </div>
    );
  }

  const isEmpty = groups.length === 0;

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 space-y-6 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-extrabold text-foreground tracking-tight">Groups</h1>
        <Button size="sm" variant="outline" onClick={() => setShowCreate(true)} className="gap-1.5">
          <Plus className="w-4 h-4" />
          New
        </Button>
      </div>

      {isEmpty ? (
        /* Empty state */
        <div className="flex flex-col items-center gap-4 py-16">
          <div className="w-16 h-16 rounded-2xl bg-muted flex items-center justify-center">
            <Users className="w-8 h-8 text-muted-foreground" />
          </div>
          <div className="text-center">
            <h2 className="text-base font-bold text-foreground">No Groups Yet</h2>
            <p className="text-sm text-muted-foreground mt-1">Create a group to organize your game nights</p>
          </div>
          <Button onClick={() => setShowCreate(true)} className="gap-2">
            <Plus className="w-4 h-4" />
            Create a Group
          </Button>
        </div>
      ) : (
        <>
          {/* My Groups — horizontal scroll */}
          <section>
            <SectionHeader title="My Groups" />
            <div className="flex gap-3 overflow-x-auto pb-2 -mx-1 px-1 scrollbar-hide">
              {groups.map(g => (
                <GroupBubble key={g.id} group={g} onClick={() => navigate(`/groups/${g.id}`)} />
              ))}
              <NewGroupBubble onClick={() => setShowCreate(true)} />
            </div>
          </section>

          {/* Upcoming Events */}
          {upcomingEvents.length > 0 && (
            <section>
              <SectionHeader title="Upcoming Events" />
              <div className="flex gap-3 overflow-x-auto pb-2 -mx-1 px-1 scrollbar-hide">
                {upcomingEvents.map(event => (
                  <div key={event.id} className="w-[200px] shrink-0">
                    <EventCard
                      event={event}
                      confirmedCount={(inviteCounts[event.id] ?? 0) + 1}
                      currentUserId={userId ?? undefined}
                      onClick={() => navigate(`/events/${event.id}`)}
                    />
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* Recent Plays */}
          {recentPlays.length > 0 && (
            <section>
              <SectionHeader title="Recent Plays" />
              <div className="divide-y divide-border/40">
                {recentPlays.map(play => (
                  <RecentPlayRow key={play.id} play={play} />
                ))}
              </div>
            </section>
          )}
        </>
      )}

      <CreateGroupDialog open={showCreate} onOpenChange={setShowCreate} onCreated={handleGroupCreated} />
    </div>
  );
}
