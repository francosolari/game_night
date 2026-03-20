import { useState, useEffect } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, ChevronRight, Edit2, Save, X, Minus as MinusIcon, Plus as PlusIcon, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Slider } from "@/components/ui/slider";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/contexts/AuthContext";
import { GameThumbnail } from "@/components/game/GameThumbnail";
import { RatingBadge } from "@/components/game/RatingBadge";
import { ComplexityBadge } from "@/components/game/ComplexityBadge";
import { InfoRowGroup, type InfoRowData } from "@/components/game/InfoRowGroup";
import { TagFlowSection } from "@/components/game/TagFlowSection";
import { HorizontalGameScroll } from "@/components/game/HorizontalGameScroll";
import { fetchGameById, fetchExpansions, fetchBaseGame, fetchFamilyMembers, updateGame } from "@/lib/gameQueries";
import type { Game } from "@/lib/types";
import { playerCountDisplay, playtimeDisplay, complexityLabel, complexityColorClass, formatPlayerRanges } from "@/lib/types";

export default function GameDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();

  const { data: game, isLoading, refetch } = useQuery({
    queryKey: ["game", id],
    queryFn: () => fetchGameById(id!),
    enabled: !!id,
  });

  const { data: expansions = [] } = useQuery({
    queryKey: ["gameExpansions", id],
    queryFn: () => fetchExpansions(id!),
    enabled: !!id,
    retry: false,
    staleTime: 60_000,
  });

  const { data: baseGame } = useQuery({
    queryKey: ["gameBaseGame", id],
    queryFn: () => fetchBaseGame(id!),
    enabled: !!id,
    retry: false,
    staleTime: 60_000,
  });

  const { data: families = [] } = useQuery({
    queryKey: ["gameFamilies", id],
    queryFn: () => fetchFamilyMembers(id!),
    enabled: !!id,
    retry: false,
    staleTime: 60_000,
  });

  const [isEditing, setIsEditing] = useState(false);
  const [draft, setDraft] = useState<Game | null>(null);
  const [saving, setSaving] = useState(false);
  const [descExpanded, setDescExpanded] = useState(false);

  const displayedGame = isEditing && draft ? draft : game;
  const isManual = displayedGame && !displayedGame.bgg_id && displayedGame.owner_id;
  const canEdit = isManual && displayedGame?.owner_id === user?.id;

  const startEditing = () => {
    if (game) {
      setDraft({ ...game });
      setIsEditing(true);
    }
  };

  const cancelEditing = () => {
    setDraft(null);
    setIsEditing(false);
  };

  const saveEdits = async () => {
    if (!draft || !draft.name.trim()) return;
    setSaving(true);
    try {
      await updateGame(draft);
      await refetch();
      toast({ title: "Game updated!" });
      setIsEditing(false);
      setDraft(null);
    } catch (e: any) {
      toast({ title: "Save failed", description: e.message, variant: "destructive" });
    }
    setSaving(false);
  };

  const updateDraft = (partial: Partial<Game>) => {
    if (draft) setDraft({ ...draft, ...partial });
  };

  if (isLoading) {
    return (
      <div className="max-w-3xl mx-auto px-4 pt-6 space-y-4">
        <Skeleton className="h-64 rounded-xl" />
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-40 rounded-xl" />
      </div>
    );
  }

  if (!displayedGame) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <p className="text-muted-foreground">Game not found</p>
      </div>
    );
  }

  const gameInitials = displayedGame.name.split(" ").slice(0, 2).map(w => w[0]).join("").toUpperCase() || "GM";

  const infoRows = buildInfoRows(displayedGame);

  return (
    <div className="max-w-3xl mx-auto pb-28 md:pb-8">
      {/* Toolbar */}
      <div className="flex items-center justify-between px-4 pt-4 pb-2">
        <button onClick={() => navigate(-1)} className="p-2 -ml-2 text-muted-foreground hover:text-foreground transition-colors">
          <ArrowLeft className="w-5 h-5" />
        </button>
        {isEditing ? (
          <div className="flex gap-2">
            <Button variant="ghost" size="sm" onClick={cancelEditing}><X className="w-4 h-4 mr-1" /> Cancel</Button>
            <Button size="sm" onClick={saveEdits} disabled={saving || !draft?.name.trim()}>
              {saving ? <Loader2 className="w-4 h-4 mr-1 animate-spin" /> : <Save className="w-4 h-4 mr-1" />}
              Save
            </Button>
          </div>
        ) : canEdit ? (
          <Button variant="ghost" size="sm" onClick={startEditing}><Edit2 className="w-4 h-4 mr-1" /> Edit</Button>
        ) : null}
      </div>

      {/* Hero */}
      <div className="px-4 mb-6">
        <div className="relative rounded-xl overflow-hidden">
          {displayedGame.image_url ? (
            <img
              src={displayedGame.image_url}
              alt={displayedGame.name}
              className="w-full max-h-[280px] object-cover"
            />
          ) : (
            <div className="w-full h-[280px] bg-gradient-to-br from-accent/50 to-primary/50 flex items-center justify-center">
              <span className="text-5xl font-black text-white/60">{gameInitials}</span>
            </div>
          )}
          {displayedGame.bgg_rating != null && displayedGame.bgg_rating > 0 && (
            <div className="absolute bottom-3 left-3">
              <RatingBadge rating={displayedGame.bgg_rating} size="lg" />
            </div>
          )}
        </div>
      </div>

      <div className="px-4 space-y-6">
        {/* Title cluster */}
        <div className="space-y-1">
          {isEditing && draft ? (
            <Input
              value={draft.name}
              onChange={e => updateDraft({ name: e.target.value })}
              className="text-xl font-extrabold"
              placeholder="Game Name"
            />
          ) : (
            <h1 className="text-2xl font-extrabold text-foreground">{displayedGame.name}</h1>
          )}

          {isManual && (
            <p className="text-xs text-muted-foreground flex items-center gap-1">
              {isEditing ? "✏️ Editing Manual Game" : "📝 Manual Library Game"}
            </p>
          )}

          {/* Designer / Publisher links */}
          {!isEditing && displayedGame.designers && displayedGame.designers.length > 0 && (
            <div className="flex items-center gap-1 flex-wrap">
              {displayedGame.designers.map((d, i) => (
                <span key={d}>
                  {i > 0 && <span className="text-muted-foreground mx-1">·</span>}
                  <Link to={`/games/designer/${encodeURIComponent(d)}`} className="text-sm text-accent hover:underline">
                    {d}
                  </Link>
                </span>
              ))}
            </div>
          )}
          {!isEditing && displayedGame.publishers && displayedGame.publishers.length > 0 && (
            <div className="flex items-center gap-1 flex-wrap">
              {displayedGame.publishers.slice(0, 3).map((p, i) => (
                <span key={p}>
                  {i > 0 && <span className="text-muted-foreground mx-1">·</span>}
                  <Link to={`/games/publisher/${encodeURIComponent(p)}`} className="text-sm text-accent hover:underline">
                    {p}
                  </Link>
                </span>
              ))}
            </div>
          )}
          {!isEditing && displayedGame.year_published && (
            <p className="text-xs text-muted-foreground">📅 {displayedGame.year_published}</p>
          )}
        </div>

        {/* Info rows or editor */}
        {isEditing && draft ? (
          <ManualGameEditor draft={draft} updateDraft={updateDraft} />
        ) : (
          <InfoRowGroup rows={infoRows} />
        )}

        {/* Tags */}
        {isEditing && draft ? (
          <ManualTagEditor draft={draft} updateDraft={updateDraft} />
        ) : (
          <>
            <TagFlowSection title="Categories" tags={displayedGame.categories || []} colorClass="bg-primary/10 text-primary" />
            <TagFlowSection title="Mechanics" tags={displayedGame.mechanics || []} colorClass="bg-accent/10 text-accent" />
          </>
        )}

        {/* Description */}
        {isEditing && draft ? (
          <div className="space-y-2">
            <h4 className="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">Description</h4>
            <Textarea
              value={draft.description || ""}
              onChange={e => updateDraft({ description: e.target.value || null })}
              placeholder="Add a description, notes, or house rules"
              rows={5}
              className="bg-card"
            />
          </div>
        ) : displayedGame.description ? (
          <div className="space-y-1.5">
            <p className={`text-sm text-muted-foreground ${!descExpanded ? "line-clamp-3" : ""}`}>
              {displayedGame.description}
            </p>
            <button onClick={() => setDescExpanded(!descExpanded)} className="text-xs font-semibold text-primary">
              {descExpanded ? "Show less" : "Read more"}
            </button>
          </div>
        ) : null}

        {/* Base game link */}
        {!isEditing && baseGame && (
          <button
            onClick={() => navigate(`/games/${baseGame.id}`)}
            className="w-full flex items-center gap-3 p-3 rounded-lg bg-card hover:bg-muted/50 transition-colors"
          >
            <span className="text-accent">↩</span>
            <span className="text-sm font-semibold text-accent">Expansion for {baseGame.name}</span>
            <ChevronRight className="w-4 h-4 text-muted-foreground ml-auto" />
          </button>
        )}

        {/* Families */}
        {!isEditing && families.map(f => (
          <div key={f.family.id} className="space-y-2">
            <p className="text-[11px] font-bold uppercase tracking-wider text-accent">
              Part of {f.family.name}
            </p>
            <HorizontalGameScroll
              games={f.games.filter(g => g.id !== displayedGame.id)}
            />
          </div>
        ))}

        {/* Expansions */}
        {!isEditing && expansions.length > 0 && (
          <HorizontalGameScroll title="Expansions" games={expansions} />
        )}
      </div>
    </div>
  );
}

// ─── Build Info Rows (mirrors iOS buildInfoRows) ───

function buildInfoRows(game: Game): InfoRowData[] {
  const rows: InfoRowData[] = [];

  const bestStr = formatPlayerRanges(game.recommended_players);
  rows.push({
    icon: "person.2.fill",
    label: "Players",
    value: playerCountDisplay(game),
    detail: bestStr ? `Best: ${bestStr}` : undefined,
    detailColor: "text-green-600",
  });

  rows.push({
    icon: "clock.fill",
    label: "Time",
    value: playtimeDisplay(game),
  });

  rows.push({
    icon: "scalemass.fill",
    label: "Weight",
    value: `${game.complexity.toFixed(2)} / 5`,
    detail: complexityLabel(game.complexity),
    detailColor: complexityColorClass(game.complexity).split(" ").find(c => c.startsWith("text-")) || "text-muted-foreground",
  });

  if (game.bgg_rating != null && game.bgg_rating > 0) {
    rows.push({
      icon: "star.fill",
      label: "Rating",
      value: `${game.bgg_rating.toFixed(1)} / 10`,
    });
  }

  if (game.min_age != null) {
    rows.push({
      icon: "number.circle",
      label: "Age",
      value: `Ages ${game.min_age}+`,
    });
  }

  return rows;
}

// ─── Manual Game Editor (mirrors iOS ManualGameEditorSection) ───

function ManualGameEditor({ draft, updateDraft }: { draft: Game; updateDraft: (p: Partial<Game>) => void }) {
  return (
    <div className="space-y-3">
      <h4 className="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">Game Details</h4>
      <div className="bg-card rounded-xl p-4 space-y-4">
        {/* Year */}
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">Published</span>
          <Input
            type="number"
            value={draft.year_published || ""}
            onChange={e => updateDraft({ year_published: parseInt(e.target.value) || null })}
            className="w-24 text-right"
            placeholder="Year"
          />
        </div>

        {/* Min Players stepper */}
        <StepperRow
          title="Minimum Players"
          value={draft.min_players}
          onDecrement={() => {
            if (draft.min_players <= 1) return;
            const newMin = draft.min_players - 1;
            updateDraft({ min_players: newMin, max_players: Math.max(draft.max_players, newMin) });
          }}
          onIncrement={() => {
            if (draft.min_players >= 20) return;
            const newMin = draft.min_players + 1;
            updateDraft({ min_players: newMin, max_players: Math.max(draft.max_players, newMin) });
          }}
        />

        {/* Max Players stepper */}
        <StepperRow
          title="Maximum Players"
          value={draft.max_players}
          onDecrement={() => {
            if (draft.max_players <= draft.min_players) return;
            updateDraft({ max_players: draft.max_players - 1 });
          }}
          onIncrement={() => {
            if (draft.max_players >= 20) return;
            updateDraft({ max_players: draft.max_players + 1 });
          }}
        />

        {/* Min Playtime stepper */}
        <StepperRow
          title="Minimum Time"
          value={draft.min_playtime}
          suffix="min"
          onDecrement={() => {
            if (draft.min_playtime <= 30) return;
            const newMin = draft.min_playtime - 30;
            updateDraft({ min_playtime: newMin, max_playtime: Math.max(draft.max_playtime, newMin) });
          }}
          onIncrement={() => {
            if (draft.min_playtime >= 600) return;
            const newMin = draft.min_playtime + 30;
            updateDraft({ min_playtime: newMin, max_playtime: Math.max(draft.max_playtime, newMin) });
          }}
        />

        {/* Max Playtime stepper */}
        <StepperRow
          title="Maximum Time"
          value={draft.max_playtime}
          suffix="min"
          onDecrement={() => {
            if (draft.max_playtime <= draft.min_playtime) return;
            updateDraft({ max_playtime: draft.max_playtime - 30 });
          }}
          onIncrement={() => {
            if (draft.max_playtime >= 600) return;
            updateDraft({ max_playtime: draft.max_playtime + 30 });
          }}
        />

        {/* Complexity slider */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-foreground">Complexity</span>
            <ComplexityBadge weight={draft.complexity} showValue />
          </div>
          <Slider
            value={[draft.complexity]}
            onValueChange={v => updateDraft({ complexity: Math.round(v[0] * 100) / 100 })}
            min={1}
            max={5}
            step={0.1}
          />
        </div>

        {/* Rating slider */}
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium text-foreground">Rating</span>
            <span className="text-sm font-semibold text-accent">{(draft.bgg_rating ?? 0).toFixed(1)}</span>
          </div>
          <Slider
            value={[draft.bgg_rating ?? 0]}
            onValueChange={v => updateDraft({ bgg_rating: Math.round(v[0] * 10) / 10 })}
            min={0}
            max={10}
            step={0.1}
          />
        </div>

        {/* Recommended Players */}
        <div className="space-y-2">
          <span className="text-sm font-medium text-foreground">Recommended Players</span>
          <div className="flex flex-wrap gap-2">
            {Array.from({ length: draft.max_players - draft.min_players + 1 }, (_, i) => draft.min_players + i).map(n => {
              const selected = (draft.recommended_players ?? []).includes(n);
              return (
                <button
                  key={n}
                  onClick={() => {
                    const current = new Set(draft.recommended_players ?? []);
                    if (current.has(n)) current.delete(n); else current.add(n);
                    updateDraft({ recommended_players: current.size > 0 ? Array.from(current).sort((a, b) => a - b) : null });
                  }}
                  className={`px-3 py-1.5 rounded-full text-sm font-semibold transition-colors ${
                    selected ? "bg-primary text-primary-foreground" : "bg-muted text-foreground"
                  }`}
                >
                  {n}
                </button>
              );
            })}
          </div>
          <p className="text-[11px] text-muted-foreground">Tap to mark the best player counts.</p>
        </div>

        {/* Min Age */}
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">Recommended Age</span>
          <div className="flex items-center gap-2">
            {draft.min_age != null ? (
              <>
                <button onClick={() => updateDraft({ min_age: null })} className="text-xs text-primary font-semibold">Clear</button>
                <button
                  onClick={() => updateDraft({ min_age: Math.max(1, (draft.min_age ?? 8) - 1) })}
                  className="w-7 h-7 rounded-full bg-muted flex items-center justify-center"
                >
                  <MinusIcon className="w-3 h-3" />
                </button>
                <span className="text-sm font-semibold w-8 text-center">{draft.min_age}+</span>
                <button
                  onClick={() => updateDraft({ min_age: Math.min(21, (draft.min_age ?? 8) + 1) })}
                  className="w-7 h-7 rounded-full bg-muted flex items-center justify-center"
                >
                  <PlusIcon className="w-3 h-3" />
                </button>
              </>
            ) : (
              <button onClick={() => updateDraft({ min_age: 8 })} className="text-xs text-primary font-semibold">Add Age</button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Manual Tag Editor ───

function ManualTagEditor({ draft, updateDraft }: { draft: Game; updateDraft: (p: Partial<Game>) => void }) {
  const csvBinding = (key: keyof Game) => ({
    value: ((draft[key] as string[]) || []).join(", "),
    onChange: (v: string) => {
      const arr = v.split(",").map(s => s.trim()).filter(Boolean);
      updateDraft({ [key]: arr });
    },
  });

  const cats = csvBinding("categories");
  const mechs = csvBinding("mechanics");
  const designers = csvBinding("designers");
  const publishers = csvBinding("publishers");

  return (
    <div className="space-y-3">
      <h4 className="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">Categories & Mechanics</h4>
      <div className="bg-card rounded-xl p-4 space-y-4">
        <TagField title="Categories" placeholder="Strategy, Party, Co-op" {...cats} />
        <TagField title="Mechanics" placeholder="Deck Building, Drafting" {...mechs} />
        <TagField title="Designers" placeholder="Designer names" {...designers} />
        <TagField title="Publishers" placeholder="Publisher names" {...publishers} />
      </div>
    </div>
  );
}

function TagField({ title, placeholder, value, onChange }: { title: string; placeholder: string; value: string; onChange: (v: string) => void }) {
  return (
    <div className="space-y-1">
      <span className="text-sm font-medium text-foreground">{title}</span>
      <Input
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
      />
    </div>
  );
}

// ─── Stepper Row ───

function StepperRow({ title, value, suffix, onDecrement, onIncrement }: {
  title: string; value: number; suffix?: string; onDecrement: () => void; onIncrement: () => void;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm font-medium text-foreground">{title}</span>
      <div className="flex items-center gap-2">
        <button onClick={onDecrement} className="w-7 h-7 rounded-full bg-muted flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors">
          <MinusIcon className="w-3 h-3" />
        </button>
        <span className="text-sm font-semibold min-w-[60px] text-center">
          {value}{suffix ? ` ${suffix}` : ""}
        </span>
        <button onClick={onIncrement} className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-primary hover:bg-primary/20 transition-colors">
          <PlusIcon className="w-3 h-3" />
        </button>
      </div>
    </div>
  );
}
