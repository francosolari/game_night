import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { ArrowLeft, CalendarPlus, Gamepad2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { MembersTab } from "@/components/groups/MembersTab";
import { PlayHistoryTab } from "@/components/groups/PlayHistoryTab";
import { StatsTab } from "@/components/groups/StatsTab";
import { ChatTab } from "@/components/groups/ChatTab";
import { LogPlayDialog } from "@/components/groups/LogPlayDialog";
import { toast } from "sonner";
import { fetchGroups, fetchPlaysForGroup, removeGroupMember, deletePlay } from "@/lib/groupQueries";
import type { GameGroup, Play } from "@/lib/groupTypes";

export default function GroupDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [group, setGroup] = useState<GameGroup | null>(null);
  const isOwner = !!(user && group && group.owner_id === user.id);
  const [plays, setPlays] = useState<Play[]>([]);
  const [loading, setLoading] = useState(true);
  const [showLogPlay, setShowLogPlay] = useState(false);

  const loadGroup = useCallback(async () => {
    if (!id) return;
    try {
      const groups = await fetchGroups();
      const found = groups.find(g => g.id === id);
      if (found) setGroup(found);
    } catch {
      toast.error("Failed to load group");
    }
  }, [id]);

  const loadPlays = useCallback(async () => {
    if (!id) return;
    try {
      const data = await fetchPlaysForGroup(id);
      setPlays(data);
    } catch {
      // table may not exist
    }
  }, [id]);

  useEffect(() => {
    (async () => {
      setLoading(true);
      await Promise.all([loadGroup(), loadPlays()]);
      setLoading(false);
    })();
  }, [loadGroup, loadPlays]);

  const handleRemoveMember = async (memberId: string) => {
    try {
      await removeGroupMember(memberId);
      toast.success("Member removed");
      await loadGroup();
    } catch {
      toast.error("Failed to remove member");
    }
  };

  const handleDeletePlay = async (playId: string) => {
    try {
      await deletePlay(playId);
      toast.success("Play deleted");
      await loadPlays();
    } catch {
      toast.error("Failed to delete play");
    }
  };

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-6 space-y-4 pb-24">
        <Skeleton className="h-6 w-40" />
        <Skeleton className="h-20 w-full rounded-xl" />
        <Skeleton className="h-64 w-full rounded-xl" />
      </div>
    );
  }

  if (!group) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <p className="text-muted-foreground">Group not found</p>
        <Button variant="outline" onClick={() => navigate("/groups")} className="mt-4">Back to Groups</Button>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 space-y-5 pb-24">
      {/* Back */}
      <button onClick={() => navigate("/groups")} className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors">
        <ArrowLeft className="w-4 h-4" />
        Groups
      </button>

      {/* Header */}
      <div className="flex items-start gap-4">
        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary/30 to-accent/30 flex items-center justify-center text-2xl border-2 border-primary/20 shrink-0">
          {group.emoji || group.name.charAt(0).toUpperCase()}
        </div>
        <div className="flex-1 min-w-0">
          <h1 className="text-lg font-extrabold text-foreground tracking-tight">{group.name}</h1>
          {group.description && <p className="text-sm text-muted-foreground mt-0.5">{group.description}</p>}
          <p className="text-xs text-muted-foreground mt-1">
            {group.members.length} {group.members.length === 1 ? "member" : "members"}
          </p>
        </div>
      </div>

      {/* Quick actions */}
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          className="flex-1 gap-2"
          onClick={() => navigate(`/events/new?groupId=${group.id}`)}
        >
          <CalendarPlus className="w-4 h-4" />
          Schedule Night
        </Button>
        <Button
          variant="outline"
          size="sm"
          className="flex-1 gap-2"
          onClick={() => setShowLogPlay(true)}
        >
          <Gamepad2 className="w-4 h-4" />
          Log a Play
        </Button>
      </div>

      {/* Tabs */}
      <Tabs defaultValue="members" className="w-full">
        <TabsList className="w-full grid grid-cols-4 bg-muted/60">
          <TabsTrigger value="members" className="text-xs">Members</TabsTrigger>
          <TabsTrigger value="history" className="text-xs">History</TabsTrigger>
          <TabsTrigger value="stats" className="text-xs">Stats</TabsTrigger>
          <TabsTrigger value="chat" className="text-xs">Chat</TabsTrigger>
        </TabsList>
        <TabsContent value="members" className="mt-4">
          <MembersTab group={group} onMemberRemoved={handleRemoveMember} onMemberAdded={loadGroup} isOwner={isOwner} />
        </TabsContent>
        <TabsContent value="history" className="mt-4">
          <PlayHistoryTab plays={plays} members={group.members} onDelete={handleDeletePlay} />
        </TabsContent>
        <TabsContent value="stats" className="mt-4">
          <StatsTab plays={plays} members={group.members} />
        </TabsContent>
        <TabsContent value="chat" className="mt-4">
          <ChatTab groupId={group.id} />
        </TabsContent>
      </Tabs>

      <LogPlayDialog
        open={showLogPlay}
        onOpenChange={setShowLogPlay}
        groupId={group.id}
        members={group.members}
        onLogged={loadPlays}
      />
    </div>
  );
}
