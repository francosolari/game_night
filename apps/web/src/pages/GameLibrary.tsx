import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Search, Plus, Download, FolderPlus, X, Dice5, Loader2 } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/contexts/AuthContext";
import { GameCard } from "@/components/game/GameCard";
import { GameThumbnail } from "@/components/game/GameThumbnail";
import { Skeleton } from "@/components/ui/skeleton";
import {
  fetchGameLibrary,
  fetchCategories,
  removeFromLibrary,
  searchBGG,
  fetchBGGGameDetail,
  upsertGameFromBGG,
  addGameToLibrary,
  createCategory,
  type BGGSearchResult,
} from "@/lib/gameQueries";
import type { GameLibraryEntry, GameCategory } from "@/lib/types";

export default function GameLibrary() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [showAddGame, setShowAddGame] = useState(false);
  const [showImportBGG, setShowImportBGG] = useState(false);
  const [showCreateCategory, setShowCreateCategory] = useState(false);

  const { data: library = [], isLoading: libLoading } = useQuery({
    queryKey: ["gameLibrary"],
    queryFn: () => fetchGameLibrary(user!.id),
    enabled: !!user?.id,
  });

  const { data: categories = [] } = useQuery({
    queryKey: ["gameCategories"],
    queryFn: () => fetchCategories(user!.id),
    enabled: !!user?.id,
  });

  const removeMutation = useMutation({
    mutationFn: removeFromLibrary,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["gameLibrary"] });
      toast({ title: "Game removed from library" });
    },
  });

  // Filter
  const filtered = library.filter(entry => {
    if (!entry.game) return false;
    if (selectedCategory && entry.category_id !== selectedCategory) return false;
    if (searchQuery) {
      return entry.game.name.toLowerCase().includes(searchQuery.toLowerCase());
    }
    return true;
  });

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center space-y-3">
          <Dice5 className="w-12 h-12 text-muted-foreground mx-auto" />
          <p className="text-muted-foreground">Sign in to manage your game library</p>
          <Button onClick={() => navigate("/login")}>Sign In</Button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto px-4 pb-28 md:pb-8">
      {/* Header */}
      <div className="flex items-center justify-between pt-6 pb-4">
        <h1 className="text-2xl font-extrabold text-foreground">My Games</h1>
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon" onClick={() => setShowAddGame(true)} title="Search BGG">
            <Search className="w-5 h-5" />
          </Button>
          <Button variant="ghost" size="icon" onClick={() => setShowImportBGG(true)} title="Import BGG Collection">
            <Download className="w-5 h-5" />
          </Button>
          <Button variant="ghost" size="icon" onClick={() => setShowCreateCategory(true)} title="New Category">
            <FolderPlus className="w-5 h-5" />
          </Button>
        </div>
      </div>

      {/* Search */}
      <div className="relative mb-4">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <Input
          placeholder="Search your library..."
          value={searchQuery}
          onChange={e => setSearchQuery(e.target.value)}
          className="pl-10 bg-card"
        />
      </div>

      {/* Category chips */}
      {categories.length > 0 && (
        <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-3">
          <button
            onClick={() => setSelectedCategory(null)}
            className={`shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${
              !selectedCategory ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
            }`}
          >
            All
          </button>
          {categories.map(cat => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={`shrink-0 px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${
                selectedCategory === cat.id ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
              }`}
            >
              {cat.icon ? `${cat.icon} ` : ""}{cat.name}
            </button>
          ))}
        </div>
      )}

      {/* Game list */}
      {libLoading ? (
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
          <Dice5 className="w-16 h-16 text-muted-foreground/40" />
          <div>
            <p className="font-bold text-foreground">No Games Yet</p>
            <p className="text-sm text-muted-foreground mt-1">
              Add games from BoardGameGeek or import your collection.
            </p>
          </div>
          <Button onClick={() => setShowAddGame(true)}>Add a Game</Button>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(entry => entry.game && (
            <GameCard
              key={entry.id}
              game={entry.game}
              onRemove={() => removeMutation.mutate(entry.id)}
            />
          ))}
        </div>
      )}

      {/* Add Game Dialog */}
      <AddGameDialog open={showAddGame} onOpenChange={setShowAddGame} />

      {/* Import BGG Dialog */}
      <ImportBGGDialog open={showImportBGG} onOpenChange={setShowImportBGG} />

      {/* Create Category Dialog */}
      <CreateCategoryDialog open={showCreateCategory} onOpenChange={setShowCreateCategory} />
    </div>
  );
}

// ─── Add Game Dialog ───

function AddGameDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<BGGSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [adding, setAdding] = useState<number | null>(null);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const doSearch = useCallback(async (q: string) => {
    if (q.length < 2) { setResults([]); return; }
    setSearching(true);
    try {
      const r = await searchBGG(q);
      setResults(r.slice(0, 20));
    } catch { /* ignore */ }
    setSearching(false);
  }, []);

  useEffect(() => {
    const t = setTimeout(() => doSearch(query), 400);
    return () => clearTimeout(t);
  }, [query, doSearch]);

  const handleAdd = async (bggId: number) => {
    setAdding(bggId);
    try {
      const detail = await fetchBGGGameDetail(bggId);
      if (!detail) throw new Error("Could not fetch game details");
      const game = await upsertGameFromBGG(detail);
      await addGameToLibrary(game.id);
      queryClient.invalidateQueries({ queryKey: ["gameLibrary"] });
      toast({ title: `${game.name} added to library!` });
      onOpenChange(false);
    } catch (e: any) {
      toast({ title: "Failed to add game", description: e.message, variant: "destructive" });
    }
    setAdding(null);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md max-h-[80vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Add Game</DialogTitle>
        </DialogHeader>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Search BoardGameGeek..."
            value={query}
            onChange={e => setQuery(e.target.value)}
            className="pl-10"
            autoFocus
          />
        </div>
        <div className="overflow-y-auto flex-1 space-y-1 min-h-0">
          {searching && (
            <div className="flex justify-center py-8">
              <Loader2 className="w-6 h-6 animate-spin text-primary" />
            </div>
          )}
          {!searching && results.map(r => (
            <button
              key={r.id}
              onClick={() => handleAdd(r.id)}
              disabled={adding === r.id}
              className="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-muted/50 transition-colors text-left"
            >
              <GameThumbnail src={r.thumbnailUrl} name={r.name} size="md" />
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-foreground text-sm truncate">{r.name}</p>
                {r.yearPublished && <p className="text-xs text-muted-foreground">({r.yearPublished})</p>}
              </div>
              {adding === r.id ? (
                <Loader2 className="w-5 h-5 animate-spin text-primary shrink-0" />
              ) : (
                <Plus className="w-5 h-5 text-primary shrink-0" />
              )}
            </button>
          ))}
          {!searching && query.length >= 2 && results.length === 0 && (
            <p className="text-center text-muted-foreground py-8 text-sm">No results found</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}

// ─── Import BGG Dialog ───

function ImportBGGDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [username, setUsername] = useState("");
  const [importing, setImporting] = useState(false);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const handleImport = async () => {
    if (!username.trim()) return;
    setImporting(true);
    try {
      const res = await fetch(`https://boardgamegeek.com/xmlapi2/collection?username=${encodeURIComponent(username)}&own=1&stats=1`);
      const text = await res.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(text, "text/xml");
      const items = doc.querySelectorAll("item");
      let count = 0;
      for (const item of Array.from(items).slice(0, 50)) {
        const bggId = parseInt(item.getAttribute("objectid") || "0");
        if (!bggId) continue;
        try {
          const detail = await fetchBGGGameDetail(bggId);
          if (!detail) continue;
          const game = await upsertGameFromBGG(detail);
          await addGameToLibrary(game.id);
          count++;
        } catch { /* skip individual failures */ }
      }
      queryClient.invalidateQueries({ queryKey: ["gameLibrary"] });
      toast({ title: `Imported ${count} games!` });
      onOpenChange(false);
    } catch (e: any) {
      toast({ title: "Import failed", description: e.message, variant: "destructive" });
    }
    setImporting(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>Import from BoardGameGeek</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-muted-foreground">Enter your BGG username to import your game collection.</p>
        <Input
          placeholder="BGG Username"
          value={username}
          onChange={e => setUsername(e.target.value)}
          autoFocus
        />
        <Button onClick={handleImport} disabled={!username.trim() || importing} className="w-full">
          {importing ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Importing...</> : "Import Collection"}
        </Button>
      </DialogContent>
    </Dialog>
  );
}

// ─── Create Category Dialog ───

function CreateCategoryDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const [name, setName] = useState("");
  const [icon, setIcon] = useState<string | null>(null);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const iconOptions = ["⭐", "❤️", "⚡", "👑", "🏆", "🧩", "🎭", "🗺️", "⏱️", "🎲", "🃏", "🧠"];

  const handleCreate = async () => {
    if (!name.trim()) return;
    try {
      await createCategory(name.trim(), icon);
      queryClient.invalidateQueries({ queryKey: ["gameCategories"] });
      toast({ title: `Category "${name}" created!` });
      onOpenChange(false);
      setName("");
      setIcon(null);
    } catch (e: any) {
      toast({ title: "Failed to create category", description: e.message, variant: "destructive" });
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>New Category</DialogTitle>
        </DialogHeader>
        <Input
          placeholder="Category Name"
          value={name}
          onChange={e => setName(e.target.value)}
          autoFocus
        />
        <div>
          <p className="text-xs text-muted-foreground mb-2">Icon (optional)</p>
          <div className="grid grid-cols-6 gap-2">
            {iconOptions.map(ic => (
              <button
                key={ic}
                onClick={() => setIcon(icon === ic ? null : ic)}
                className={`w-10 h-10 rounded-lg flex items-center justify-center text-lg transition-colors ${
                  icon === ic ? "bg-primary/15 ring-2 ring-primary" : "bg-muted hover:bg-muted/80"
                }`}
              >
                {ic}
              </button>
            ))}
          </div>
        </div>
        <Button onClick={handleCreate} disabled={!name.trim()} className="w-full">
          Create Category
        </Button>
      </DialogContent>
    </Dialog>
  );
}
