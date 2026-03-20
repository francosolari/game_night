import { useNavigate } from "react-router-dom";
import { GameThumbnail } from "./GameThumbnail";
import type { Game } from "@/lib/types";

interface Props {
  title?: string;
  games: Game[];
}

export function HorizontalGameScroll({ title, games }: Props) {
  const navigate = useNavigate();
  if (games.length === 0) return null;

  return (
    <div className="space-y-2">
      {title && (
        <h4 className="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">{title}</h4>
      )}
      <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-1">
        {games.map(game => (
          <button
            key={game.id}
            onClick={() => navigate(`/games/${game.id}`)}
            className="shrink-0 w-[100px] text-center group"
          >
            <GameThumbnail src={game.image_url || game.thumbnail_url} name={game.name} size="lg" className="mx-auto" />
            <p className="text-[11px] font-semibold text-foreground mt-1.5 line-clamp-2 group-hover:text-primary transition-colors">
              {game.name}
            </p>
            {game.bgg_rating != null && game.bgg_rating > 0 && (
              <p className="text-[9px] text-muted-foreground">★ {game.bgg_rating.toFixed(1)}</p>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}
