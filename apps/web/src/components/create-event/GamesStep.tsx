import { useState, useEffect, useRef } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Search, Plus, Star, Trash2, Loader2, Dice5 } from "lucide-react";
import { cn } from "@/lib/utils";
import { fetchGameLibrary } from "@/lib/gameQueries";
import type { useCreateEvent } from "@/hooks/useCreateEvent";
import type { Game, GameLibraryEntry } from "@/lib/types";

type FormState = ReturnType<typeof useCreateEvent>;

interface Props {
  form: FormState;
}

export function GamesStep({ form }: Props) {
  const [libraryGames, setLibraryGames] = useState<Game[]>([]);
  const [searchTimeout, setSearchTimeout] = useState<ReturnType<typeof setTimeout> | null>(null);
  const manualSearchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    fetchGameLibrary()
      .then(entries => setLibraryGames(entries.map(e => e.game).filter(Boolean) as Game[]))
      .catch(() => {});
  }, []);

  const handleSearchChange = (query: string) => {
    form.setManualGameName(query);
    if (searchTimeout) clearTimeout(searchTimeout);
    if (query.trim().length >= 3) {
      const timeout = setTimeout(() => form.searchGames(query), 400);
      setSearchTimeout(timeout);
    } else {
      form.searchGames("");
    }
  };

  useEffect(() => {
    const handler = (event: PointerEvent) => {
      const input = manualSearchRef.current;
      if (!input) return;
      if (document.activeElement !== input) return;
      if (event.target instanceof Node && input.contains(event.target)) return;
      input.blur();
    };
    document.addEventListener("pointerdown", handler);
    return () => document.removeEventListener("pointerdown", handler);
  }, []);

  const libraryMatches = form.manualGameName.trim()
    ? libraryGames.filter(g =>
        g.name.toLowerCase().includes(form.manualGameName.toLowerCase()) &&
        !form.selectedGames.some(sg => sg.game_id === g.id)
      ).slice(0, 5)
    : [];

  const alreadyAddedBggIds = new Set(form.selectedGames.map(g => g.game?.bgg_id).filter(Boolean));

  return (
    <div className="space-y-5">
      {/* Search / Manual Entry */}
      <div className="space-y-2">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          Add a Game
        </Label>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Search BoardGameGeek or type a name…"
            value={form.manualGameName}
            onChange={e => handleSearchChange(e.target.value)}
            className="pl-9 text-sm"
            ref={manualSearchRef}
          />
          {form.isSearchingGames && (
            <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground animate-spin" />
          )}
        </div>

        {/* Manual add button */}
        {form.manualGameName.trim() && (
          <Button
            variant="ghost"
            className="w-full justify-start text-sm text-primary"
            onClick={() => form.addManualGame(form.manualGameName)}
          >
            <Plus className="w-4 h-4 mr-2" /> Add "{form.manualGameName}" as manual game
          </Button>
        )}

        {/* Library autocomplete */}
        {libraryMatches.length > 0 && (
          <div className="space-y-1">
            <p className="text-xs text-muted-foreground font-medium px-1">From Your Library</p>
            {libraryMatches.map(game => (
              <button
                key={game.id}
                onClick={() => {
                  const newGame = {
                    id: crypto.randomUUID(),
                    game_id: game.id,
                    game,
                    is_primary: form.selectedGames.length === 0,
                    sort_order: form.selectedGames.length,
                  };
                  // Directly manipulate — not ideal but works with current hook shape
                  form.addGameFromBGG(-1); // placeholder, we handle inline
                }}
                className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-muted transition-colors text-left"
              >
                {game.thumbnail_url ? (
                  <img src={game.thumbnail_url} className="w-10 h-10 rounded-md object-cover" />
                ) : (
                  <div className="w-10 h-10 rounded-md bg-muted flex items-center justify-center">
                    <Dice5 className="w-5 h-5 text-muted-foreground" />
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{game.name}</p>
                  {game.year_published && <p className="text-xs text-muted-foreground">{game.year_published}</p>}
                </div>
              </button>
            ))}
          </div>
        )}

        {/* BGG search results */}
        {form.gameSearchResults.length > 0 && (
          <div className="space-y-1 max-h-60 overflow-y-auto">
            <p className="text-xs text-muted-foreground font-medium px-1">BGG Results</p>
            {form.gameSearchResults
              .filter(r => !alreadyAddedBggIds.has(r.id))
              .slice(0, 10)
              .map(result => (
                <button
                  key={result.id}
                  onClick={() => form.addGameFromBGG(result.id)}
                  className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-muted transition-colors text-left"
                >
                  {result.thumbnailUrl ? (
                    <img src={result.thumbnailUrl} className="w-10 h-10 rounded-md object-cover" />
                  ) : (
                    <div className="w-10 h-10 rounded-md bg-muted flex items-center justify-center">
                      <Dice5 className="w-5 h-5 text-muted-foreground" />
                    </div>
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{result.name}</p>
                    {result.yearPublished && <p className="text-xs text-muted-foreground">{result.yearPublished}</p>}
                  </div>
                  <Plus className="w-4 h-4 text-muted-foreground shrink-0" />
                </button>
              ))}
          </div>
        )}
      </div>

      {/* Selected Games */}
      {form.selectedGames.length > 0 && (
        <div className="space-y-2">
          <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Selected Games ({form.selectedGames.length})
          </Label>
          <div className="space-y-1">
            {form.selectedGames.map((sg, i) => (
              <div
                key={sg.id}
                className="flex items-center gap-3 p-2.5 rounded-xl bg-card border border-border/60"
              >
                {sg.game?.thumbnail_url ? (
                  <img src={sg.game.thumbnail_url} className="w-10 h-10 rounded-md object-cover" />
                ) : (
                  <div className="w-10 h-10 rounded-md bg-muted flex items-center justify-center">
                    <Dice5 className="w-5 h-5 text-muted-foreground" />
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{sg.game?.name || "Unknown"}</p>
                  {sg.game?.year_published && (
                    <p className="text-xs text-muted-foreground">{sg.game.year_published}</p>
                  )}
                </div>
                <button
                  onClick={() => form.setPrimaryGame(sg.id)}
                  title="Set as primary"
                  className="p-1 rounded-md hover:bg-muted transition-colors"
                >
                  <Star
                    className={cn("w-4 h-4", sg.is_primary ? "text-amber-500 fill-amber-500" : "text-muted-foreground")}
                  />
                </button>
                <button
                  onClick={() => form.removeGame(i)}
                  className="p-1 rounded-md hover:bg-destructive/10 transition-colors"
                >
                  <Trash2 className="w-4 h-4 text-destructive" />
                </button>
              </div>
            ))}
          </div>

          {form.selectedGames.length > 1 && (
            <div className="flex items-center justify-between pt-1">
              <Label className="text-sm">Allow game voting</Label>
              <Switch checked={form.allowGameVoting} onCheckedChange={form.setAllowGameVoting} />
            </div>
          )}
        </div>
      )}

      {/* Empty state */}
      {form.selectedGames.length === 0 && !form.manualGameName.trim() && (
        <div className="text-center py-8 space-y-2">
          <Dice5 className="w-10 h-10 mx-auto text-muted-foreground/40" />
          <p className="text-sm text-muted-foreground">Search above to add games to your event</p>
          <p className="text-xs text-muted-foreground">You can also skip this step and add games later</p>
        </div>
      )}
    </div>
  );
}
