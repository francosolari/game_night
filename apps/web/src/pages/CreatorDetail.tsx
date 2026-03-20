import { useParams, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowLeft, Star, Scale, Loader2 } from "lucide-react";
import { useState } from "react";
import { GameThumbnail } from "@/components/game/GameThumbnail";
import { RatingBadge } from "@/components/game/RatingBadge";
import { ComplexityBadge } from "@/components/game/ComplexityBadge";
import { InfoRowGroup, type InfoRowData } from "@/components/game/InfoRowGroup";
import { fetchGamesByCreator } from "@/lib/gameQueries";
import type { Game } from "@/lib/types";

type SortMode = "topRated" | "byYear" | "byWeight";

export default function CreatorDetail() {
  const { name, role } = useParams<{ name: string; role: string }>();
  const navigate = useNavigate();
  const decodedName = decodeURIComponent(name || "");
  const creatorRole = (role === "publisher" ? "publisher" : "designer") as "designer" | "publisher";
  const [sortMode, setSortMode] = useState<SortMode>("topRated");

  const { data: games = [], isLoading } = useQuery({
    queryKey: ["creatorGames", decodedName, creatorRole],
    queryFn: () => fetchGamesByCreator(decodedName, creatorRole),
    enabled: !!decodedName,
  });

  const sorted = [...games].sort((a, b) => {
    switch (sortMode) {
      case "topRated": return (b.bgg_rating ?? 0) - (a.bgg_rating ?? 0);
      case "byYear": return (b.year_published ?? 0) - (a.year_published ?? 0);
      case "byWeight": return b.complexity - a.complexity;
    }
  });

  const initials = decodedName.split(" ").slice(0, 2).map(w => w[0]).join("").toUpperCase();
  const avgRating = games.length > 0
    ? games.reduce((s, g) => s + (g.bgg_rating ?? 0), 0) / games.filter(g => g.bgg_rating).length || 0
    : 0;
  const avgWeight = games.length > 0
    ? games.reduce((s, g) => s + g.complexity, 0) / games.length
    : 0;

  const statsRows: InfoRowData[] = [];
  if (avgRating > 0) statsRows.push({ icon: "star.fill", label: "Avg. Rating", value: `Avg. Rating: ${avgRating.toFixed(1)}` });
  if (avgWeight > 0) statsRows.push({ icon: "scalemass.fill", label: "Avg. Weight", value: `Avg. Weight: ${avgWeight.toFixed(1)} / 5` });

  return (
    <div className="max-w-3xl mx-auto pb-28 md:pb-8">
      <div className="px-4 pt-4 pb-2">
        <button onClick={() => navigate(-1)} className="p-2 -ml-2 text-muted-foreground hover:text-foreground transition-colors">
          <ArrowLeft className="w-5 h-5" />
        </button>
      </div>

      {/* Hero */}
      <div className="px-4 mb-6">
        <div className="w-full h-[200px] rounded-xl bg-gradient-to-br from-accent/50 to-primary/50 flex items-center justify-center">
          <span className="text-5xl font-black text-white/60">{initials}</span>
        </div>
      </div>

      <div className="px-4 space-y-6">
        <div>
          <h1 className="text-2xl font-extrabold text-foreground">{decodedName}</h1>
          <p className="text-sm text-muted-foreground capitalize">{creatorRole} · {games.length} game{games.length !== 1 ? "s" : ""}</p>
        </div>

        {statsRows.length > 0 && <InfoRowGroup rows={statsRows} />}

        {isLoading ? (
          <div className="flex justify-center py-12">
            <Loader2 className="w-6 h-6 animate-spin text-primary" />
          </div>
        ) : games.length === 0 ? (
          <p className="text-muted-foreground text-sm py-8 text-center">No games found in the database yet.</p>
        ) : (
          <>
            {/* Sort bar */}
            <div className="flex gap-2">
              {(["topRated", "byYear", "byWeight"] as SortMode[]).map(mode => (
                <button
                  key={mode}
                  onClick={() => setSortMode(mode)}
                  className={`px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${
                    sortMode === mode ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
                  }`}
                >
                  {mode === "topRated" ? "Top Rated" : mode === "byYear" ? "By Year" : "By Weight"}
                </button>
              ))}
            </div>

            {/* Game grid */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {sorted.map(game => (
                <button
                  key={game.id}
                  onClick={() => navigate(`/games/${game.id}`)}
                  className="text-left group rounded-xl overflow-hidden bg-card hover:bg-muted/50 transition-colors"
                >
                  <GameThumbnail src={game.image_url || game.thumbnail_url} name={game.name} size="xl" />
                  <div className="p-2 space-y-0.5">
                    <p className="text-xs font-bold text-foreground line-clamp-2 group-hover:text-primary transition-colors">
                      {game.name}
                    </p>
                    <div className="flex items-center gap-1.5">
                      {game.year_published && <span className="text-[10px] text-muted-foreground">{game.year_published}</span>}
                      <ComplexityBadge weight={game.complexity} />
                    </div>
                    {game.bgg_rating != null && game.bgg_rating > 0 && (
                      <RatingBadge rating={game.bgg_rating} size="sm" />
                    )}
                  </div>
                </button>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
