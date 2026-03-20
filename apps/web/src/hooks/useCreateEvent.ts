import { useState, useCallback, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import {
  createEventRecord,
  updateEventRecord,
  createEventGames,
  upsertEventGames,
  deleteEventGames,
  createTimeOptions,
  upsertTimeOptions,
  deleteTimeOptions,
  createInvites,
  updateInvite,
  deleteInvites,
  fetchInvitesForSync,
} from "@/lib/eventMutations";
import { searchBGG, fetchBGGGameDetail, upsertGameFromBGG } from "@/lib/gameQueries";
import { fetchEventById } from "@/lib/queries";
import type { GameEvent, EventGame, TimeOption, Game, EventVisibility, InviteStrategy } from "@/lib/types";

export type CreateStep = "details" | "games" | "invites" | "review";
const STEPS: CreateStep[] = ["details", "games", "invites", "review"];

export interface InviteeEntry {
  id: string;
  name: string;
  phoneNumber: string;
  userId?: string | null;
  tier: number;
  groupId?: string | null;
  groupEmoji?: string | null;
  groupName?: string | null;
}

interface SelectedGame {
  id: string;
  game_id: string;
  game: Game | null;
  is_primary: boolean;
  sort_order: number;
}

export function useCreateEvent() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const editId = searchParams.get("edit");

  // Load event for edit mode
  const { data: eventToEdit } = useQuery({
    queryKey: ["event-edit", editId],
    queryFn: () => fetchEventById(editId!),
    enabled: !!editId,
  });

  const isEditing = !!editId && !!eventToEdit;
  const isDraftEdit = isEditing && eventToEdit?.status === "draft";

  // ─── Form state ───
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [visibility, setVisibility] = useState<EventVisibility>("private");
  const [rsvpDeadline, setRsvpDeadline] = useState<Date | null>(null);
  const [allowGuestInvites, setAllowGuestInvites] = useState(false);
  const [location, setLocation] = useState("");
  const [locationAddress, setLocationAddress] = useState("");
  const [scheduleMode, setScheduleMode] = useState<"fixed" | "poll">("fixed");
  const [allowTimeSuggestions, setAllowTimeSuggestions] = useState(true);
  const [allowGameVoting, setAllowGameVoting] = useState(false);
  const [minPlayers, setMinPlayers] = useState(2);
  const [maxPlayers, setMaxPlayers] = useState<number | null>(4);
  const [plusOneLimit, setPlusOneLimit] = useState(0);
  const [allowMaybeRSVP, setAllowMaybeRSVP] = useState(true);
  const [requirePlusOneNames, setRequirePlusOneNames] = useState(false);
  const [coverVariant, setCoverVariant] = useState(0);
  const previewEventId = useMemo(() => editId || crypto.randomUUID(), [editId]);

  // Schedule
  const [fixedDate, setFixedDate] = useState<Date>(new Date());
  const [fixedStartTime, setFixedStartTime] = useState("19:00");
  const [fixedEndTime, setFixedEndTime] = useState("22:00");
  const [hasEndTime, setHasEndTime] = useState(false);
  const [hasDate, setHasDate] = useState(true);
  const [timeOptions, setTimeOptions] = useState<TimeOption[]>([]);

  // Games
  const [selectedGames, setSelectedGames] = useState<SelectedGame[]>([]);
  const [gameSearchQuery, setGameSearchQuery] = useState("");
  const [gameSearchResults, setGameSearchResults] = useState<any[]>([]);
  const [isSearchingGames, setIsSearchingGames] = useState(false);
  const [manualGameName, setManualGameName] = useState("");

  // Invites
  const [invitees, setInvitees] = useState<InviteeEntry[]>([]);

  // Navigation
  const [currentStep, setCurrentStep] = useState<CreateStep>("details");
  const [completedSteps, setCompletedSteps] = useState<Set<CreateStep>>(new Set());
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Initialize from edit event
  const [initialized, setInitialized] = useState(false);
  if (eventToEdit && !initialized) {
    setTitle(eventToEdit.title);
    setDescription(eventToEdit.description || "");
    setVisibility(eventToEdit.visibility);
    setAllowGuestInvites(eventToEdit.allow_guest_invites);
    setLocation(eventToEdit.location || "");
    setLocationAddress(eventToEdit.location_address || "");
    setScheduleMode(eventToEdit.schedule_mode);
    setAllowTimeSuggestions(eventToEdit.allow_time_suggestions);
    setAllowGameVoting(eventToEdit.allow_game_voting ?? false);
    setMinPlayers(eventToEdit.min_players);
    setMaxPlayers(eventToEdit.max_players ?? null);
    setPlusOneLimit(eventToEdit.plus_one_limit ?? 0);
    setAllowMaybeRSVP(eventToEdit.allow_maybe_rsvp ?? true);
    setRequirePlusOneNames(eventToEdit.require_plus_one_names ?? false);
    setCoverVariant(eventToEdit.cover_variant ?? 0);

    if (eventToEdit.schedule_mode === "fixed" && eventToEdit.time_options?.[0]) {
      const to = eventToEdit.time_options[0];
      setFixedDate(new Date(to.start_time));
      const st = new Date(to.start_time);
      setFixedStartTime(`${String(st.getHours()).padStart(2, "0")}:${String(st.getMinutes()).padStart(2, "0")}`);
      if (to.end_time) {
        const et = new Date(to.end_time);
        setFixedEndTime(`${String(et.getHours()).padStart(2, "0")}:${String(et.getMinutes()).padStart(2, "0")}`);
        setHasEndTime(true);
      }
      setHasDate(true);
    } else if (eventToEdit.schedule_mode === "poll") {
      setTimeOptions(eventToEdit.time_options || []);
    }

    if (eventToEdit.games?.length) {
      setSelectedGames(
        eventToEdit.games.map((eg: EventGame) => ({
          id: eg.id,
          game_id: eg.game_id,
          game: eg.game || null,
          is_primary: eg.is_primary,
          sort_order: eg.sort_order,
        }))
      );
    }

    if (!isDraftEdit) {
      setCompletedSteps(new Set(STEPS));
    }

    setInitialized(true);
  }

  // ─── Step navigation ───
  const stepIndex = STEPS.indexOf(currentStep);

  const canProceed = useMemo(() => {
    if (currentStep === "details") return title.trim().length > 0;
    return true;
  }, [currentStep, title]);

  const navigateToStep = useCallback(
    (step: CreateStep) => {
      setCurrentStep(step);
    },
    []
  );

  const goNext = useCallback(() => {
    if (!canProceed) return;
    setCompletedSteps(prev => new Set([...prev, currentStep]));
    const nextIdx = stepIndex + 1;
    if (nextIdx < STEPS.length) {
      setCurrentStep(STEPS[nextIdx]);
    }
  }, [canProceed, currentStep, stepIndex]);

  const goBack = useCallback(() => {
    if (stepIndex > 0) setCurrentStep(STEPS[stepIndex - 1]);
  }, [stepIndex]);

  const nextButtonLabel = useMemo(() => {
    if (isEditing && !isDraftEdit) return "Save Changes";
    if (currentStep === "review") return invitees.length === 0 ? "Create Event" : "Send Invites";
    if (currentStep === "games" && selectedGames.length === 0) return "Add Game Later";
    if (currentStep === "invites" && invitees.length === 0) return "Invite Later";
    return "Next";
  }, [currentStep, isEditing, isDraftEdit, invitees.length, selectedGames.length]);

  // ─── Game actions ───
  const searchGames = useCallback(async (query: string) => {
    setGameSearchQuery(query);
    if (!query.trim()) {
      setGameSearchResults([]);
      return;
    }
    setIsSearchingGames(true);
    try {
      const results = await searchBGG(query);
      setGameSearchResults(results);
    } catch (e: any) {
      setError(e.message);
    }
    setIsSearchingGames(false);
  }, []);

  const addGameFromBGG = useCallback(async (bggId: number) => {
    try {
      const detail = await fetchBGGGameDetail(bggId);
      if (!detail) throw new Error("Could not fetch game details");
      const saved = await upsertGameFromBGG(detail);
      const newGame: SelectedGame = {
        id: crypto.randomUUID(),
        game_id: saved.id,
        game: saved as Game,
        is_primary: selectedGames.length === 0,
        sort_order: selectedGames.length,
      };
      setSelectedGames(prev => [...prev, newGame]);
      toast.success(`Added ${saved.name}`);
    } catch (e: any) {
      toast.error(e.message);
    }
  }, [selectedGames.length]);

  const addManualGame = useCallback(async (name: string) => {
    if (!name.trim()) return;
    try {
      const { data, error } = await supabase
        .from("games")
        .insert({ name, min_players: 2, max_players: 4, min_playtime: 60, max_playtime: 120, complexity: 0 })
        .select()
        .single();
      if (error) throw error;
      const newGame: SelectedGame = {
        id: crypto.randomUUID(),
        game_id: data.id,
        game: data as Game,
        is_primary: selectedGames.length === 0,
        sort_order: selectedGames.length,
      };
      setSelectedGames(prev => [...prev, newGame]);
      setManualGameName("");
      toast.success(`Added ${name}`);
    } catch (e: any) {
      toast.error(e.message);
    }
  }, [selectedGames.length]);

  const removeGame = useCallback((index: number) => {
    setSelectedGames(prev => prev.filter((_, i) => i !== index));
  }, []);

  const setPrimaryGame = useCallback((gameId: string) => {
    setSelectedGames(prev =>
      prev.map(g => ({ ...g, is_primary: g.id === gameId }))
    );
  }, []);

  // ─── Time option actions ───
  const addTimeOption = useCallback(
    (date: string, startTime: string, endTime?: string | null, label?: string | null) => {
      const option: TimeOption = {
        id: crypto.randomUUID(),
        event_id: null,
        date,
        start_time: startTime,
        end_time: endTime || null,
        label: label || null,
        is_suggested: false,
        suggested_by: null,
        vote_count: 0,
        maybe_count: 0,
      };
      setTimeOptions(prev => [...prev, option].sort((a, b) => a.start_time.localeCompare(b.start_time)));
    },
    []
  );

  const removeTimeOption = useCallback((id: string) => {
    setTimeOptions(prev => prev.filter(t => t.id !== id));
  }, []);

  // ─── Invitee actions ───
  const addInvitee = useCallback((name: string, phoneNumber: string, tier: number = 1) => {
    if (!phoneNumber.trim()) return;
    const entry: InviteeEntry = {
      id: crypto.randomUUID(),
      name: name || phoneNumber,
      phoneNumber,
      userId: null,
      tier,
    };
    setInvitees(prev => [...prev, entry]);
  }, []);

  const removeInvitee = useCallback((id: string) => {
    setInvitees(prev => prev.filter(i => i.id !== id));
  }, []);

  const setInviteeTier = useCallback((id: string, tier: number) => {
    setInvitees(prev => prev.map(i => (i.id === id ? { ...i, tier } : i)));
  }, []);

  const tier1Invitees = invitees.filter(i => i.tier === 1);
  const tier2Invitees = invitees.filter(i => i.tier === 2);

  // ─── Build helpers ───
  function resolvedTimeOptionsForSave(eventId: string): { id: string; event_id: string; date: string; start_time: string; end_time?: string | null; label?: string | null; is_suggested: boolean }[] {
    if (scheduleMode === "fixed") {
      if (!hasDate) return [];
      const dateStr = fixedDate.toISOString().split("T")[0];
      const startISO = new Date(`${dateStr}T${fixedStartTime}:00`).toISOString();
      const endISO = hasEndTime ? new Date(`${dateStr}T${fixedEndTime}:00`).toISOString() : null;
      const existingId = eventToEdit?.time_options?.[0]?.id || crypto.randomUUID();
      return [{ id: existingId, event_id: eventId, date: dateStr, start_time: startISO, end_time: endISO, label: null, is_suggested: false }];
    }
    return timeOptions.map(t => ({
      id: t.id,
      event_id: eventId,
      date: t.date,
      start_time: t.start_time,
      end_time: t.end_time,
      label: t.label,
      is_suggested: t.is_suggested,
    }));
  }

  function buildEventPayload(status: string, hostId: string, eventId: string) {
    return {
      id: eventId,
      host_id: hostId,
      title,
      description: description || null,
      visibility,
      rsvp_deadline: rsvpDeadline?.toISOString() || null,
      allow_guest_invites: allowGuestInvites,
      location: location || null,
      location_address: locationAddress || null,
      status,
      schedule_mode: scheduleMode,
      allow_time_suggestions: scheduleMode === "poll" ? allowTimeSuggestions : false,
      invite_strategy: { type: "all_at_once", auto_promote: true } as any,
      min_players: minPlayers,
      max_players: maxPlayers,
      allow_game_voting: allowGameVoting,
      plus_one_limit: plusOneLimit,
      allow_maybe_rsvp: allowMaybeRSVP,
      require_plus_one_names: requirePlusOneNames,
      cover_variant: coverVariant,
      draft_invitees: status === "draft"
        ? invitees.map(i => ({ id: i.id, name: i.name, phone_number: i.phoneNumber, user_id: i.userId, tier: i.tier, group_id: i.groupId, group_emoji: i.groupEmoji, group_name: i.groupName }))
        : null,
    };
  }

  // ─── Persistence ───
  const saveDraft = useCallback(async () => {
    if (!user) return;
    setIsSaving(true);
    setError(null);
    try {
      const eventId = editId || crypto.randomUUID();
      const payload = buildEventPayload("draft", user.id, eventId);

      if (isEditing) {
        const { id, host_id, ...updateFields } = payload;
        await updateEventRecord(eventId, updateFields);
        await syncEventGames(eventId);
        await syncTimeOptions(eventId);
      } else {
        await createEventRecord(payload);
        await createEventGames(
          eventId,
          selectedGames.map((g, i) => ({ id: g.id, game_id: g.game_id, is_primary: g.is_primary, sort_order: i }))
        );
        await createTimeOptions(resolvedTimeOptionsForSave(eventId));
      }

      queryClient.invalidateQueries({ queryKey: ["drafts"] });
      queryClient.invalidateQueries({ queryKey: ["events"] });
      toast.success("Draft saved");
      navigate("/dashboard");
    } catch (e: any) {
      setError(e.message);
      toast.error(e.message);
    }
    setIsSaving(false);
  }, [user, editId, isEditing, title, selectedGames, timeOptions, invitees, scheduleMode, fixedDate, fixedStartTime, fixedEndTime, hasEndTime, hasDate]);

  const submitEvent = useCallback(async () => {
    if (!user) return;
    setIsSaving(true);
    setError(null);
    try {
      const eventId = editId || crypto.randomUUID();
      const status = isEditing
        ? isDraftEdit ? "published" : (eventToEdit?.status || "published")
        : "published";
      const payload = buildEventPayload(status, user.id, eventId);

      if (isEditing) {
        const { id, host_id, ...updateFields } = payload;
        await updateEventRecord(eventId, updateFields);
        await syncEventGames(eventId);
        await syncTimeOptions(eventId);
        await syncInviteRecords(eventId, user.id);
      } else {
        await createEventRecord(payload);
        await createEventGames(
          eventId,
          selectedGames.map((g, i) => ({ id: g.id, game_id: g.game_id, is_primary: g.is_primary, sort_order: i }))
        );
        await createTimeOptions(resolvedTimeOptionsForSave(eventId));
        await createInviteRecords(eventId, user.id);
      }

      queryClient.invalidateQueries({ queryKey: ["events"] });
      queryClient.invalidateQueries({ queryKey: ["drafts"] });
      toast.success(isEditing ? "Event updated!" : "Event created!");
      navigate(`/events/${eventId}`);
    } catch (e: any) {
      setError(e.message);
      toast.error(e.message);
    }
    setIsSaving(false);
  }, [user, editId, isEditing, isDraftEdit, eventToEdit, title, selectedGames, timeOptions, invitees, scheduleMode, fixedDate, fixedStartTime, fixedEndTime, hasEndTime, hasDate]);

  async function syncEventGames(eventId: string) {
    const existingIds = new Set(eventToEdit?.games?.map((g: EventGame) => g.id) || []);
    const currentGames = selectedGames.map((g, i) => ({ id: g.id, game_id: g.game_id, is_primary: g.is_primary, sort_order: i }));
    const currentIds = new Set(currentGames.map(g => g.id));
    await upsertEventGames(eventId, currentGames);
    await deleteEventGames([...existingIds].filter(id => !currentIds.has(id)));
  }

  async function syncTimeOptions(eventId: string) {
    const existingIds = new Set(eventToEdit?.time_options?.map((t: TimeOption) => t.id) || []);
    const currentOptions = resolvedTimeOptionsForSave(eventId);
    const currentIds = new Set(currentOptions.map(t => t.id));
    await upsertTimeOptions(currentOptions);
    await deleteTimeOptions([...existingIds].filter(id => !currentIds.has(id)));
  }

  async function createInviteRecords(eventId: string, hostId: string) {
    if (invitees.length === 0) return;
    const rows = invitees.map((inv, index) => ({
      id: inv.id,
      event_id: eventId,
      user_id: inv.userId || null,
      phone_number: inv.phoneNumber,
      display_name: inv.name,
      status: inv.tier > 1 ? "waitlisted" : "pending",
      tier: inv.tier,
      tier_position: index,
      is_active: inv.tier <= 1,
      sent_via: "both",
    }));
    await createInvites(rows);
  }

  async function syncInviteRecords(eventId: string, hostId: string) {
    const existing = await fetchInvitesForSync(eventId);
    const existingById = new Map(existing.map((inv: any) => [inv.id, inv]));
    const currentIds = new Set(invitees.map(i => i.id));

    const toDelete = existing.filter((inv: any) => !currentIds.has(inv.id)).map((inv: any) => inv.id);
    await deleteInvites(toDelete);

    const newInvites: any[] = [];
    for (const [index, entry] of invitees.entries()) {
      const existingInv = existingById.get(entry.id);
      if (existingInv) {
        const isBench = entry.tier > 1;
        await updateInvite(entry.id, {
          phone_number: entry.phoneNumber,
          display_name: entry.name,
          tier: entry.tier,
          tier_position: index,
          is_active: !isBench,
          status: isBench ? "waitlisted" : (existingInv.status === "waitlisted" ? "pending" : existingInv.status),
        });
      } else {
        newInvites.push({
          id: entry.id,
          event_id: eventId,
          user_id: entry.userId || null,
          phone_number: entry.phoneNumber,
          display_name: entry.name,
          status: entry.tier > 1 ? "waitlisted" : "pending",
          tier: entry.tier,
          tier_position: index,
          is_active: entry.tier <= 1,
          sent_via: "both",
        });
      }
    }
    await createInvites(newInvites);
  }

  // ─── Primary action handler ───
  const handlePrimaryAction = useCallback(() => {
    if (isEditing && !isDraftEdit) {
      submitEvent();
      return;
    }
    if (currentStep === "review") {
      submitEvent();
      return;
    }
    goNext();
  }, [isEditing, isDraftEdit, currentStep, submitEvent, goNext]);

  return {
    // State
    title, setTitle,
    description, setDescription,
    visibility, setVisibility,
    rsvpDeadline, setRsvpDeadline,
    allowGuestInvites, setAllowGuestInvites,
    location, setLocation,
    locationAddress, setLocationAddress,
    scheduleMode, setScheduleMode,
    allowTimeSuggestions, setAllowTimeSuggestions,
    allowGameVoting, setAllowGameVoting,
    minPlayers, setMinPlayers,
    maxPlayers, setMaxPlayers,
    plusOneLimit, setPlusOneLimit,
    allowMaybeRSVP, setAllowMaybeRSVP,
    requirePlusOneNames, setRequirePlusOneNames,
    coverVariant, setCoverVariant,
    previewEventId,
    fixedDate, setFixedDate,
    fixedStartTime, setFixedStartTime,
    fixedEndTime, setFixedEndTime,
    hasEndTime, setHasEndTime,
    hasDate, setHasDate,
    timeOptions, setTimeOptions, addTimeOption, removeTimeOption,
    selectedGames, removeGame, setPrimaryGame,
    gameSearchQuery, gameSearchResults, isSearchingGames, searchGames, addGameFromBGG,
    manualGameName, setManualGameName, addManualGame,
    invitees, addInvitee, removeInvitee, setInviteeTier,
    tier1Invitees, tier2Invitees,
    currentStep, setCurrentStep: navigateToStep,
    completedSteps,
    canProceed,
    nextButtonLabel,
    isEditing, isDraftEdit,
    isSaving, error,
    goNext, goBack,
    handlePrimaryAction,
    saveDraft,
    submitEvent,
    navigate,
  };
}
