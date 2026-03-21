import { useState, useEffect, useCallback, useMemo } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { supabase } from "@/lib/supabase";
import {
  fetchEventById,
  fetchInvitesForEvent,
  fetchActivityFeed,
  fetchMyGameVotes,
  fetchTimePollVoters,
  fetchGamePollVoters,
  respondToInviteRPC,
  postComment as postCommentQuery,
  postAnnouncement as postAnnouncementQuery,
  togglePinFeedItem,
  upsertGameVote,
  deleteGameVote,
  confirmTimeOptionRPC,
  confirmGameRPC,
  softDeleteEvent,
} from "@/lib/queries";
import type {
  GameEvent,
  Invite,
  ActivityFeedItem,
  GameVote,
  GameVoteType,
  TimeOptionVoter,
  GameVoterInfo,
  InviteSummary,
  EventAccessPolicy,
  EventViewerRole,
} from "@/lib/types";
import { buildAccessPolicy, buildInviteSummary } from "@/lib/types";

export function useEventDetail(eventId: string | undefined) {
  const { user } = useAuth();
  const [event, setEvent] = useState<GameEvent | null>(null);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [myInvite, setMyInvite] = useState<Invite | null>(null);
  const [activityFeed, setActivityFeed] = useState<ActivityFeedItem[]>([]);
  const [gameVotes, setGameVotes] = useState<GameVote[]>([]);
  const [myGameVotes, setMyGameVotes] = useState<Record<string, GameVoteType>>({});
  const [timeOptionVoters, setTimeOptionVoters] = useState<Record<string, TimeOptionVoter[]>>({});
  const [gameVoterDetails, setGameVoterDetails] = useState<Record<string, GameVoterInfo[]>>({});
  const [pollVotes, setPollVotes] = useState<Record<string, string>>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isSending, setIsSending] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isPostingComment, setIsPostingComment] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isOwner = useMemo(() => {
    if (!event || !user) return false;
    return event.host_id === user.id;
  }, [event, user]);

  const isCompleted = useMemo(() => {
    if (!event) return false;
    return event.status === "completed" || event.status === "cancelled";
  }, [event]);

  const hasRSVPd = useMemo(() => {
    if (!myInvite) return false;
    return myInvite.status === "accepted" || myInvite.status === "maybe";
  }, [myInvite]);

  const viewerRole: EventViewerRole = useMemo(() => {
    if (isOwner) return "host";
    if (hasRSVPd) return "rsvpd";
    if (myInvite) return "invitedNotRSVPd";
    return "publicViewer";
  }, [isOwner, hasRSVPd, myInvite]);

  const accessPolicy: EventAccessPolicy | null = useMemo(() => {
    if (!event) return null;
    return buildAccessPolicy(event, viewerRole);
  }, [event, viewerRole]);

  const canSeeActivityFeed = hasRSVPd || isOwner;

  const hasPollsActive = useMemo(() => {
    if (!event) return false;
    const hasTimePoll = event.schedule_mode === "poll" && event.time_options.length > 1 && !event.confirmed_time_option_id;
    const hasGamePoll = event.allow_game_voting && event.games.length > 1 && !event.confirmed_game_id;
    return hasTimePoll || hasGamePoll;
  }, [event]);

  const hasDatePollPending = useMemo(() => {
    if (!event) return false;
    return event.schedule_mode === "poll" && event.time_options.length > 1 && !event.confirmed_time_option_id;
  }, [event]);

  const inviteSummary: InviteSummary = useMemo(() => {
    if (!event) return { total: 0, accepted: 0, declined: 0, pending: 0, maybe: 0, waitlisted: 0, acceptedUsers: [], pendingUsers: [], maybeUsers: [], declinedUsers: [], waitlistedUsers: [] };
    return buildInviteSummary(invites, event);
  }, [invites, event]);

  const canInviteGuests = accessPolicy?.canInviteGuests ?? false;

  // Group activity feed items
  const groupedFeed = useMemo(() => {
    const topLevel: ActivityFeedItem[] = [];
    const repliesByParent: Record<string, ActivityFeedItem[]> = {};

    for (const item of activityFeed) {
      if (item.parent_id) {
        (repliesByParent[item.parent_id] ??= []).push(item);
      } else {
        topLevel.push(item);
      }
    }

    return topLevel
      .map(item => ({
        ...item,
        replies: repliesByParent[item.id]?.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime()),
      }))
      .sort((a, b) => {
        if (a.is_pinned !== b.is_pinned) return a.is_pinned ? -1 : 1;
        return new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
      });
  }, [activityFeed]);

  const loadEvent = useCallback(async () => {
    if (!eventId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [ev, inv] = await Promise.all([
        fetchEventById(eventId),
        fetchInvitesForEvent(eventId),
      ]);
      setEvent(ev);
      setInvites(inv);

      if (user) {
        const mine = inv.find(i => i.user_id === user.id);
        setMyInvite(mine || null);
      }

      // Load secondary data
      const [feedItems, gVotes] = await Promise.allSettled([
        fetchActivityFeed(eventId),
        fetchMyGameVotes(eventId),
      ]);

      if (feedItems.status === "fulfilled") setActivityFeed(feedItems.value);
      if (gVotes.status === "fulfilled") {
        setGameVotes(gVotes.value);
        if (user) {
          const mine: Record<string, GameVoteType> = {};
          for (const v of gVotes.value) {
            if (v.user_id === user.id) mine[v.game_id] = v.vote_type;
          }
          setMyGameVotes(mine);
        }
      }

      // Voter details
      const [tvResult, gvResult] = await Promise.allSettled([
        fetchTimePollVoters(eventId),
        fetchGamePollVoters(eventId),
      ]);

      if (tvResult.status === "fulfilled") {
        const grouped: Record<string, TimeOptionVoter[]> = {};
        for (const v of tvResult.value) {
          (grouped[v.time_option_id] ??= []).push(v);
        }
        setTimeOptionVoters(grouped);
      }

      if (gvResult.status === "fulfilled") {
        const grouped: Record<string, GameVoterInfo[]> = {};
        for (const v of gvResult.value) {
          (grouped[v.game_id] ??= []).push(v);
        }
        setGameVoterDetails(grouped);
      }
    } catch (err) {
      setError((err as Error).message);
    }
    setIsLoading(false);
  }, [eventId, user]);

  const refreshData = useCallback(async () => {
    if (!eventId) return;
    try {
      const [ev, inv, feedItems, gVotes, tvResult, gvResult] = await Promise.allSettled([
        fetchEventById(eventId),
        fetchInvitesForEvent(eventId),
        fetchActivityFeed(eventId),
        fetchMyGameVotes(eventId),
        fetchTimePollVoters(eventId),
        fetchGamePollVoters(eventId),
      ]);

      if (ev.status === "fulfilled") setEvent(ev.value);
      if (inv.status === "fulfilled") {
        setInvites(inv.value);
        if (user) setMyInvite(inv.value.find(i => i.user_id === user.id) || null);
      }
      if (feedItems.status === "fulfilled") setActivityFeed(feedItems.value);
      if (gVotes.status === "fulfilled") {
        setGameVotes(gVotes.value);
        if (user) {
          const mine: Record<string, GameVoteType> = {};
          for (const v of gVotes.value) {
            if (v.user_id === user.id) mine[v.game_id] = v.vote_type;
          }
          setMyGameVotes(mine);
        }
      }
      if (tvResult.status === "fulfilled") {
        const grouped: Record<string, TimeOptionVoter[]> = {};
        for (const v of tvResult.value) (grouped[v.time_option_id] ??= []).push(v);
        setTimeOptionVoters(grouped);
      }
      if (gvResult.status === "fulfilled") {
        const grouped: Record<string, GameVoterInfo[]> = {};
        for (const v of gvResult.value) (grouped[v.game_id] ??= []).push(v);
        setGameVoterDetails(grouped);
      }
    } catch {
      // Non-critical for refresh
    }
  }, [eventId, user]);

  // Initial load
  useEffect(() => {
    loadEvent();
  }, [loadEvent]);

  // Realtime subscriptions
  useEffect(() => {
    if (!eventId) return;

    const channel = supabase
      .channel(`event-detail-${eventId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "activity_feed", filter: `event_id=eq.${eventId}` }, () => {
        fetchActivityFeed(eventId).then(setActivityFeed).catch(() => {});
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "invites", filter: `event_id=eq.${eventId}` }, () => {
        refreshData();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [eventId, refreshData]);

  // Mutations
  const respondToInvite = useCallback(async (status: string, votes: { time_option_id: string; vote_type: string }[] = []) => {
    if (!myInvite) return;
    setIsSending(true);
    try {
      await respondToInviteRPC(myInvite.id, status, votes);
      setMyInvite(prev => prev ? { ...prev, status: status as Invite["status"] } : null);
      await refreshData();
    } catch (err) {
      setError((err as Error).message);
      throw err;
    } finally {
      setIsSending(false);
    }
  }, [myInvite, refreshData]);

  const voteForGame = useCallback(async (gameId: string, voteType: GameVoteType) => {
    if (!eventId) return;
    try {
      if (myGameVotes[gameId] === voteType) {
        await deleteGameVote(eventId, gameId);
        setMyGameVotes(prev => { const n = { ...prev }; delete n[gameId]; return n; });
      } else {
        await upsertGameVote(eventId, gameId, voteType);
        setMyGameVotes(prev => ({ ...prev, [gameId]: voteType }));
      }
      await refreshData();
    } catch (err) {
      setError((err as Error).message);
    }
  }, [eventId, myGameVotes, refreshData]);

  const confirmTimeOption = useCallback(async (timeOptionId: string) => {
    if (!eventId) return;
    try {
      await confirmTimeOptionRPC(eventId, timeOptionId);
      await loadEvent();
    } catch (err) {
      setError((err as Error).message);
    }
  }, [eventId, loadEvent]);

  const confirmGame = useCallback(async (gameId: string) => {
    if (!eventId || !event) return;
    const gameName = event.games.find(g => g.game_id === gameId)?.game?.name ?? "a game";
    try {
      await confirmGameRPC(eventId, gameId, gameName);
      await loadEvent();
    } catch (err) {
      setError((err as Error).message);
    }
  }, [eventId, event, loadEvent]);

  const postComment = useCallback(async (content: string, parentId?: string | null) => {
    if (!eventId) return;
    setIsPostingComment(true);
    try {
      await postCommentQuery(eventId, content, parentId);
      const items = await fetchActivityFeed(eventId);
      setActivityFeed(items);
    } catch (err) {
      setError((err as Error).message);
    }
    setIsPostingComment(false);
  }, [eventId]);

  const postAnnouncementFn = useCallback(async (content: string) => {
    if (!eventId) return;
    setIsPostingComment(true);
    try {
      await postAnnouncementQuery(eventId, content);
      const items = await fetchActivityFeed(eventId);
      setActivityFeed(items);
    } catch (err) {
      setError((err as Error).message);
    }
    setIsPostingComment(false);
  }, [eventId]);

  const togglePin = useCallback(async (itemId: string, isPinned: boolean) => {
    if (!eventId) return;
    try {
      await togglePinFeedItem(itemId, isPinned);
      const items = await fetchActivityFeed(eventId);
      setActivityFeed(items);
    } catch (err) {
      setError((err as Error).message);
    }
  }, [eventId]);

  const deleteEventFn = useCallback(async () => {
    if (!eventId) return false;
    setIsDeleting(true);
    try {
      await softDeleteEvent(eventId);
      setIsDeleting(false);
      return true;
    } catch (err) {
      setError((err as Error).message);
      setIsDeleting(false);
      return false;
    }
  }, [eventId]);

  return {
    event,
    invites,
    myInvite,
    isLoading,
    isSending,
    isDeleting,
    isPostingComment,
    error,
    isOwner,
    isCompleted,
    hasRSVPd,
    viewerRole,
    accessPolicy,
    canSeeActivityFeed,
    hasPollsActive,
    hasDatePollPending,
    inviteSummary,
    canInviteGuests,
    groupedFeed,
    gameVotes,
    myGameVotes,
    timeOptionVoters,
    gameVoterDetails,
    pollVotes,
    setPollVotes,
    // Mutations
    respondToInvite,
    voteForGame,
    confirmTimeOption,
    confirmGame,
    postComment,
    postAnnouncement: postAnnouncementFn,
    togglePin,
    deleteEvent: deleteEventFn,
    refreshData,
    loadEvent,
  };
}
