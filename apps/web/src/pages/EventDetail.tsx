import { useParams, useNavigate, Link } from "react-router-dom";
import { ArrowLeft, MoreHorizontal, Pencil, Trash2, Users, Loader2 } from "lucide-react";
import { PlayerCountIndicator } from "@/components/PlayerCountIndicator";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useToast } from "@/hooks/use-toast";
import { useEventDetail } from "@/hooks/useEventDetail";
import { EventHeroHeader } from "@/components/event-detail/EventHeroHeader";
import { RSVPDialog } from "@/components/event-detail/RSVPDialog";
import { GamesSection } from "@/components/event-detail/GamesSection";
import { GuestListTabs } from "@/components/event-detail/GuestListTabs";
import { ActivityFeed } from "@/components/event-detail/ActivityFeed";
import { GuestListFullPage } from "@/components/event-detail/GuestListFullPage";
import { Skeleton } from "@/components/ui/skeleton";
import { useState } from "react";

const EventDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [showRSVP, setShowRSVP] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showGuestList, setShowGuestList] = useState(false);

  const detail = useEventDetail(id);

  const {
    event,
    isLoading,
    isOwner,
    hasRSVPd,
    myInvite,
    accessPolicy,
    canSeeActivityFeed,
    hasPollsActive,
    hasDatePollPending,
    inviteSummary,
    canInviteGuests,
    groupedFeed,
    myGameVotes,
    gameVoterDetails,
    pollVotes,
    setPollVotes,
    isSending,
    isDeleting,
    isPostingComment,
    respondToInvite,
    voteForGame,
    confirmTimeOption,
    confirmGame,
    postComment,
    postAnnouncement,
    togglePin,
    deleteEvent,
  } = detail;

  const handleDelete = async () => {
    const ok = await deleteEvent();
    if (ok) {
      toast({ title: "Event deleted", description: "The event has been removed." });
      navigate("/dashboard");
    }
  };

  const handleRSVPSubmit = async (status: string, votes: { time_option_id: string; vote_type: string }[]) => {
    try {
      await respondToInvite(status, votes);
      const msg = status === "accepted" ? "You're going!" : status === "maybe" ? "Maybe next time!" : "RSVP updated";
      toast({ title: msg });
    } catch {
      toast({ title: "Failed to update RSVP", description: "Please try again.", variant: "destructive" });
    }
  };

  const guestListMode = (() => {
    if (isOwner || hasRSVPd) return "fullList" as const;
    return "countsWithBlocker" as const;
  })();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background">
        <div className="max-w-3xl mx-auto px-4 py-8 space-y-4">
          <Skeleton className="h-[330px] w-full rounded-xl" />
          <Skeleton className="h-24 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-2">
          <p className="text-lg font-semibold text-foreground">Event not found</p>
          <Link to="/dashboard" className="text-sm text-primary font-medium">Go back</Link>
        </div>
      </div>
    );
  }

  // ─── MOBILE LAYOUT ───
  const mobileView = (
    <div className="md:hidden min-h-screen bg-background pb-24">
      {/* Delete overlay */}
      {isDeleting && (
        <div className="fixed inset-0 z-50 bg-background/80 flex items-center justify-center">
          <div className="bg-card p-6 rounded-xl flex flex-col items-center gap-3">
            <Loader2 className="w-6 h-6 animate-spin text-primary" />
            <span className="text-sm font-medium text-foreground">Deleting event...</span>
          </div>
        </div>
      )}

      {/* Back button overlay */}
      <div className="fixed top-0 left-0 z-40 p-3">
        <button
          onClick={() => navigate(-1)}
          className="w-9 h-9 rounded-full bg-black/40 backdrop-blur-sm text-white flex items-center justify-center active:scale-95 transition-transform"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
      </div>

      {/* Host toolbar */}
      {isOwner && (
        <div className="fixed top-0 right-0 z-40 p-3 flex items-center gap-2">
          <button
            onClick={() => navigate(`/events/${event.id}/edit`)}
            className="px-3 py-1.5 rounded-full bg-black/40 backdrop-blur-sm text-white text-xs font-semibold active:scale-95 transition-transform"
          >
            Edit
          </button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button className="w-9 h-9 rounded-full bg-black/40 backdrop-blur-sm text-white flex items-center justify-center">
                <MoreHorizontal className="w-5 h-5" />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => setShowDeleteConfirm(true)} className="text-destructive">
                <Trash2 className="w-4 h-4 mr-2" /> Delete Event
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      )}

      {/* Hero */}
      <EventHeroHeader
        event={event}
        myInvite={myInvite}
        confirmedCount={inviteSummary.accepted}
        hasPollsActive={hasPollsActive}
        onRSVPTap={() => setShowRSVP(true)}
      />

      {/* Content sections */}
      <div className="px-5 py-6 space-y-6">
        {/* Games */}
        <GamesSection
          event={event}
          myGameVotes={myGameVotes}
          isOwner={isOwner}
          gameVoterDetails={gameVoterDetails}
          onVote={voteForGame}
          onConfirm={isOwner ? confirmGame : null}
        />

        {/* Description */}
        {event.description && (
          <p className="text-sm text-muted-foreground leading-relaxed">{event.description}</p>
        )}

        {/* Guest List */}
        <GuestListTabs
          summary={inviteSummary}
          visibilityMode={guestListMode}
          blockerMessage="RSVP to see who's going."
          isHost={isOwner}
          canInvite={canInviteGuests}
          onViewAll={() => setShowGuestList(true)}
        />

        {/* Activity Feed */}
        <ActivityFeed
          feed={groupedFeed}
          canSee={canSeeActivityFeed}
          isHost={isOwner}
          isPosting={isPostingComment}
          onPostComment={postComment}
          onPostAnnouncement={postAnnouncement}
          onTogglePin={togglePin}
        />
      </div>
    </div>
  );

  // ─── DESKTOP LAYOUT ───
  const desktopView = (
    <div className="hidden md:block min-h-screen bg-background">
      {/* Delete overlay */}
      {isDeleting && (
        <div className="fixed inset-0 z-50 bg-background/80 flex items-center justify-center">
          <div className="bg-card p-6 rounded-xl flex flex-col items-center gap-3">
            <Loader2 className="w-6 h-6 animate-spin text-primary" />
            <span className="text-sm font-medium text-foreground">Deleting event...</span>
          </div>
        </div>
      )}

      {/* Top nav */}
      <header className="sticky top-0 z-30 bg-card/80 backdrop-blur-sm border-b border-border">
        <div className="max-w-5xl mx-auto flex items-center justify-between px-6 py-3">
          <div className="flex items-center gap-3">
            <button onClick={() => navigate(-1)} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center hover:bg-muted/80 transition-colors">
              <ArrowLeft className="w-4 h-4 text-foreground" />
            </button>
            <h1 className="text-lg font-bold text-foreground truncate">{event.title}</h1>
          </div>
          {isOwner && (
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={() => navigate(`/events/${event.id}/edit`)}>
                <Pencil className="w-3.5 h-3.5 mr-1.5" /> Edit
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="icon" className="rounded-full">
                    <MoreHorizontal className="w-5 h-5" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => setShowDeleteConfirm(true)} className="text-destructive">
                    <Trash2 className="w-4 h-4 mr-2" /> Delete Event
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          )}
        </div>
      </header>

      {/* Two-column layout */}
      <div className="max-w-5xl mx-auto px-6 py-6">
        <div className="flex gap-6">
          {/* Main column */}
          <div className="flex-1 min-w-0 space-y-6">
            {/* Hero — shorter on desktop */}
            <div className="rounded-xl overflow-hidden" style={{ height: "280px" }}>
              <EventHeroHeader
                event={event}
                myInvite={myInvite}
                confirmedCount={inviteSummary.accepted}
                hasPollsActive={hasPollsActive}
                onRSVPTap={() => setShowRSVP(true)}
              />
            </div>

            {/* Games */}
            <GamesSection
              event={event}
              myGameVotes={myGameVotes}
              isOwner={isOwner}
              gameVoterDetails={gameVoterDetails}
              onVote={voteForGame}
              onConfirm={isOwner ? confirmGame : null}
            />

            {/* Description */}
            {event.description && (
              <div className="rounded-xl bg-card border border-border p-4">
                <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground mb-2">About</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{event.description}</p>
              </div>
            )}

            {/* Activity Feed */}
            <ActivityFeed
              feed={groupedFeed}
              canSee={canSeeActivityFeed}
              isHost={isOwner}
              isPosting={isPostingComment}
              onPostComment={postComment}
              onPostAnnouncement={postAnnouncement}
              onTogglePin={togglePin}
            />
          </div>

          {/* Right sidebar */}
          <aside className="w-[280px] xl:w-[300px] shrink-0 space-y-6">
            {/* RSVP card */}
            {myInvite && (
              <div className="rounded-xl bg-card border border-border p-4 space-y-3">
                <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">Your RSVP</h3>
                <div className="flex items-center gap-2">
                  <StatusDot status={myInvite.status} />
                  <span className="text-sm font-semibold text-foreground capitalize">
                    {myInvite.status === "accepted" ? "Going" : myInvite.status === "declined" ? "Can't Go" : myInvite.status}
                  </span>
                </div>
                <Button onClick={() => setShowRSVP(true)} variant="outline" size="sm" className="w-full">
                  {myInvite.status === "pending" ? (hasPollsActive ? "RSVP & Vote" : "RSVP Now") : "Update RSVP"}
                </Button>
              </div>
            )}

            {/* Event info summary */}
            <div className="rounded-xl bg-card border border-border p-4 space-y-3">
              <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">Details</h3>
              {event.time_options[0] && (
                <InfoRow
                  label="Date"
                  value={new Date(event.time_options[0].start_time).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
                />
              )}
              {event.time_options[0] && (
                <InfoRow
                  label="Time"
                  value={new Date(event.time_options[0].start_time).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}
                />
              )}
              {event.location && <InfoRow label="Location" value={event.location} />}
              {event.host && <InfoRow label="Host" value={event.host.display_name} />}
              {event.min_players > 0 && (
                <div className="flex justify-between items-start gap-2">
                  <span className="text-xs text-muted-foreground shrink-0">Players</span>
                  <PlayerCountIndicator
                    confirmedCount={inviteSummary.accepted}
                    minPlayers={event.min_players}
                    maxPlayers={event.max_players}
                    size="standard"
                  />
                </div>
              )}
            </div>

            {/* Guest List */}
            <GuestListTabs
              summary={inviteSummary}
              visibilityMode={guestListMode}
              blockerMessage="RSVP to see who's going."
              isHost={isOwner}
              canInvite={canInviteGuests}
              onViewAll={() => setShowGuestList(true)}
            />
          </aside>
        </div>
      </div>
    </div>
  );

  return (
    <>
      {mobileView}
      {desktopView}

      {/* RSVP Dialog */}
      {event && myInvite && (
        <RSVPDialog
          open={showRSVP}
          onOpenChange={setShowRSVP}
          event={event}
          currentStatus={myInvite.status}
          isSending={isSending}
          pollVotes={pollVotes}
          onPollVoteChange={(optionId, voteType) => setPollVotes(prev => ({ ...prev, [optionId]: voteType }))}
          onSubmit={handleRSVPSubmit}
        />
      )}

      {/* Delete confirmation */}
      <AlertDialog open={showDeleteConfirm} onOpenChange={setShowDeleteConfirm}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete this event?</AlertDialogTitle>
            <AlertDialogDescription>This can't be undone.</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleDelete} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
              Delete Event
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Full guest list */}
      <GuestListFullPage
        open={showGuestList}
        onOpenChange={setShowGuestList}
        summary={inviteSummary}
        visibilityMode={guestListMode}
        blockerMessage="RSVP to see who's going."
        isHost={isOwner}
        canInvite={canInviteGuests}
      />
    </>
  );
};

// Small helpers
function StatusDot({ status }: { status: string }) {
  const color = status === "accepted" ? "bg-green-500" : status === "maybe" ? "bg-amber-500" : status === "declined" ? "bg-red-500" : "bg-muted-foreground";
  return <span className={`w-2 h-2 rounded-full ${color}`} />;
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between items-start gap-2">
      <span className="text-xs text-muted-foreground shrink-0">{label}</span>
      <span className="text-xs font-medium text-foreground text-right">{value}</span>
    </div>
  );
}

export default EventDetail;
