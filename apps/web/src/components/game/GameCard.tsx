import { useNavigate } from "react-router-dom";
import { Clock, Users, Trash2 } from "lucide-react";
import { GameThumbnail } from "./GameThumbnail";
import { RatingBadge } from "./RatingBadge";
import { ComplexityBadge } from "./ComplexityBadge";
import type { Game } from "@/lib/types";
import { playerCountDisplay, playtimeDisplay } from "@/lib/types";

interface Props {
  game: Game;
  onRemove?: () => void;
}

export function GameCard({ game, onRemove }: Props) {
  const navigate = useNavigate();

  return (
    <div
      className="flex items-center gap-3 p-3 rounded-xl bg-card hover:bg-muted/50 transition-colors cursor-pointer group"
      onClick={() => navigate(`/games/${game.id}`)}
    >
      <GameThumbnail src={game.image_url || game.thumbnail_url} name={game.name} size="lg" />

      <div className="flex-1 min-w-0 space-y-1">
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <p className="font-bold text-foreground group-hover:text-primary transition-colors truncate">
              {game.name}
            </p>
            {game.year_published && (
              <p className="text-[11px] text-muted-foreground">{game.year_published}</p>
            )}
          </div>
          {game.bgg_rating != null && game.bgg_rating > 0 && (
            <RatingBadge rating={game.bgg_rating} size="sm" className="shrink-0" />
          )}
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <span className="inline-flex items-center gap-1 text-[10px] text-muted-foreground">
            <Users className="w-3 h-3" />
            {playerCountDisplay(game)}
          </span>
          <span className="inline-flex items-center gap-1 text-[10px] text-muted-foreground">
            <Clock className="w-3 h-3" />
            {playtimeDisplay(game)}
          </span>
          <ComplexityBadge weight={game.complexity} />
        </div>
      </div>

      {onRemove && (
        <button
          onClick={(e) => { e.stopPropagation(); onRemove(); }}
          className="p-2 text-muted-foreground hover:text-destructive transition-colors opacity-0 group-hover:opacity-100"
        >
          <Trash2 className="w-4 h-4" />
        </button>
      )}
    </div>
  );
}
