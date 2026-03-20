import { Dice5, Clock, Brain, ChevronRight, CheckCircle, Users, Star } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useIsMobile } from "@/hooks/use-mobile";
import type { GameEvent, GameVoteType, GameVoterInfo } from "@/lib/types";

interface Props {
  event: GameEvent;
  myGameVotes: Record<string, GameVoteType>;
  isOwner: boolean;
  gameVoterDetails: Record<string, GameVoterInfo[]>;
  onVote: (gameId: string, voteType: GameVoteType) => Promise<void>;
  onConfirm: ((gameId: string) => Promise<void>) | null;
}

export function GamesSection({ event, myGameVotes, isOwner, gameVoterDetails, onVote, onConfirm }: Props) {
  const navigate = useNavigate();
  const isMobile = useIsMobile();

  if (event.games.length === 0) return null;

  const isVotingMode = event.allow_game_voting && event.games.length > 1;

  if (isVotingMode) {
    return (
      <div className="space-y-3">
        <SectionLabel title="What We're Playing" />

        {/* Horizontal scroll of vote cards */}
        <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-1">
          {event.games.map(eg => {
            const game = eg.game;
            if (!game) return null;
            const isConfirmed = event.confirmed_game_id === game.id;
            const voters = gameVoterDetails[game.id] ?? [];
            const yesVoters = voters.filter(v => v.vote_type === "yes" || v.vote_type === "maybe");

            return (
              <div
                key={eg.id}
                className={`shrink-0 w-[160px] rounded-xl p-3 space-y-2 border ${
                  isConfirmed
                    ? "bg-green-500/5 border-green-500/20"
                    : "bg-card border-border"
                }`}
              >
                {/* Thumbnail + info */}
                <button
                  onClick={() => navigate(`/games/${game.id}`)}
                  className="flex flex-col items-center gap-2 w-full"
                >
                  <GameThumbnail src={game.image_url || game.thumbnail_url} name={game.name} size="lg" />
                  <div className="text-center">
                    <p className="text-xs font-semibold text-foreground line-clamp-2">{game.name}</p>
                    <p className="text-[9px] text-muted-foreground">
                      {game.min_playtime}–{game.max_playtime}m · {game.complexity.toFixed(1)}⚖️
                    </p>
                  </div>
                </button>

                {/* Vote buttons */}
                <div className="flex justify-center gap-1">
                  {(["yes", "maybe", "no"] as GameVoteType[]).map(type => {
                    const selected = myGameVotes[game.id] === type;
                    const colors: Record<GameVoteType, string> = {
                      yes: selected ? "bg-green-500 text-white" : "bg-green-500/10 text-green-500",
                      maybe: selected ? "bg-amber-500 text-white" : "bg-amber-500/10 text-amber-500",
                      no: selected ? "bg-red-500 text-white" : "bg-red-500/10 text-red-500",
                    };
                    const icons: Record<GameVoteType, string> = { yes: "✓", maybe: "?", no: "✕" };
                    return (
                      <button
                        key={type}
                        onClick={() => onVote(game.id, type)}
                        className={`w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold transition-all active:scale-90 ${colors[type]}`}
                      >
                        {icons[type]}
                      </button>
                    );
                  })}
                </div>

                {/* Vote tallies */}
                <div className="flex justify-center gap-2">
                  {eg.yes_count > 0 && <VoteDot color="bg-green-500" count={eg.yes_count} />}
                  {eg.maybe_count > 0 && <VoteDot color="bg-amber-500" count={eg.maybe_count} />}
                  {isOwner && eg.no_count > 0 && <VoteDot color="bg-red-500" count={eg.no_count} />}
                </div>

                {/* Voter avatars */}
                {yesVoters.length > 0 && (
                  <div className="flex justify-center -space-x-1.5">
                    {yesVoters.slice(0, 3).map(v => (
                      <div key={v.user_id} className="w-5 h-5 rounded-full bg-muted border-2 border-card flex items-center justify-center text-[8px] font-bold text-muted-foreground">
                        {v.display_name?.[0]?.toUpperCase() || "?"}
                      </div>
                    ))}
                    {yesVoters.length > 3 && (
                      <div className="w-5 h-5 rounded-full bg-muted border-2 border-card flex items-center justify-center text-[7px] font-bold text-muted-foreground">
                        +{yesVoters.length - 3}
                      </div>
                    )}
                  </div>
                )}

                {/* Confirmed badge */}
                {isConfirmed && (
                  <div className="flex justify-center">
                    <span className="inline-flex items-center gap-1 text-[10px] font-bold text-green-500 bg-green-500/10 px-2 py-0.5 rounded-full">
                      <CheckCircle className="w-3 h-3" /> Confirmed
                    </span>
                  </div>
                )}

                {/* Host "Pick This" */}
                {isOwner && !isConfirmed && onConfirm && (
                  <button
                    onClick={() => onConfirm(game.id)}
                    className="w-full py-1.5 rounded-full bg-primary text-primary-foreground text-[11px] font-bold active:scale-95 transition-transform"
                  >
                    Pick This
                  </button>
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  // Single game / no voting — PrimaryGameCard
  const primaryEG = event.games.find(g => g.is_primary) || event.games[0];
  const primaryGame = primaryEG?.game;
  if (!primaryGame) return null;

  const otherGames = event.games.filter(g => g.id !== primaryEG.id && g.game);

  return (
    <div className="space-y-3">
      <div className="rounded-xl border-2 border-accent/30 bg-card p-4 space-y-3">
        {/* Label */}
        <div className="flex items-center gap-1.5 text-accent">
          <Dice5 className="w-3.5 h-3.5" />
          <span className="text-[11px] font-extrabold uppercase tracking-wide">We are playing</span>
        </div>

        {/* Primary game — clickable */}
        <button
          onClick={() => navigate(`/games/${primaryGame.id}`)}
          className="flex items-center gap-3 w-full text-left group"
        >
          <GameThumbnail src={primaryGame.image_url || primaryGame.thumbnail_url} name={primaryGame.name} size="md" />

          <div className="flex-1 min-w-0 space-y-1.5">
            <p className="font-bold text-foreground group-hover:text-primary transition-colors">{primaryGame.name}</p>
            <div className="flex flex-wrap gap-1.5">
              <Pill icon={<Clock className="w-[9px] h-[9px]" />} text={`${primaryGame.min_playtime}–${primaryGame.max_playtime}m`} />
              {primaryGame.complexity > 0 && (
                <Pill icon={<Brain className="w-[9px] h-[9px]" />} text={`${primaryGame.complexity.toFixed(1)}/5`} />
              )}
            </div>

            {/* Desktop: extra detail row */}
            {!isMobile && (
              <div className="flex flex-wrap gap-1.5 mt-1">
                {primaryGame.min_players && (
                  <Pill icon={<Users className="w-[9px] h-[9px]" />} text={`${primaryGame.min_players}–${primaryGame.max_players || primaryGame.min_players} players`} />
                )}
                {primaryGame.bgg_rating != null && primaryGame.bgg_rating > 0 && (
                  <Pill icon={<Star className="w-[9px] h-[9px]" />} text={`${primaryGame.bgg_rating.toFixed(1)} BGG`} />
                )}
                {primaryGame.year_published && (
                  <Pill icon={null} text={`${primaryGame.year_published}`} />
                )}
              </div>
            )}

            {/* Desktop: designers/categories */}
            {!isMobile && (
              <>
                {primaryGame.designers && primaryGame.designers.length > 0 && (
                  <p className="text-[10px] text-muted-foreground mt-1">
                    By {primaryGame.designers.slice(0, 2).join(", ")}
                  </p>
                )}
                {primaryGame.categories && primaryGame.categories.length > 0 && (
                  <div className="flex gap-1 mt-1">
                    {primaryGame.categories.slice(0, 3).map(cat => (
                      <span key={cat} className="text-[9px] font-medium px-1.5 py-0.5 rounded bg-accent/10 text-accent">
                        {cat}
                      </span>
                    ))}
                  </div>
                )}
              </>
            )}
          </div>

          <ChevronRight className="w-3 h-3 text-muted-foreground shrink-0 group-hover:text-primary transition-colors" />
        </button>

        {/* Other games — with thumbnails and clickable */}
        {otherGames.length > 0 && (
          <>
            <div className="border-t border-border" />
            <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide">
              <span className="text-[10px] text-muted-foreground shrink-0">Also playing</span>
              {otherGames.map(eg => eg.game && (
                <button
                  key={eg.id}
                  onClick={() => navigate(`/games/${eg.game!.id}`)}
                  className="flex items-center gap-1.5 shrink-0 group/also hover:bg-muted/50 rounded-lg px-1 py-0.5 transition-colors"
                >
                  <GameThumbnail src={eg.game.image_url || eg.game.thumbnail_url} name={eg.game.name} size="sm" />
                  <span className="text-xs font-bold text-muted-foreground group-hover/also:text-foreground transition-colors">{eg.game.name}</span>
                </button>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ─── Shared sub-components ───

function GameThumbnail({ src, name, size }: { src?: string | null; name: string; size: "sm" | "md" | "lg" }) {
  const dims = size === "sm" ? "w-6 h-6" : size === "md" ? "w-14 h-14" : "w-16 h-16";
  const iconDims = size === "sm" ? "w-3 h-3" : size === "md" ? "w-5 h-5" : "w-6 h-6";
  const radius = size === "sm" ? "rounded" : "rounded-lg";

  if (src) {
    return <img src={src} alt={name} className={`${dims} ${radius} object-cover shrink-0`} />;
  }
  return (
    <div className={`${dims} ${radius} bg-muted flex items-center justify-center shrink-0`}>
      <Dice5 className={`${iconDims} text-muted-foreground`} />
    </div>
  );
}

function SectionLabel({ title }: { title: string }) {
  return <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">{title}</h3>;
}

function VoteDot({ color, count }: { color: string; count: number }) {
  return (
    <div className="flex items-center gap-0.5">
      <div className={`w-[5px] h-[5px] rounded-full ${color}`} />
      <span className="text-[10px] font-medium text-muted-foreground">{count}</span>
    </div>
  );
}

function Pill({ icon, text }: { icon: React.ReactNode | null; text: string }) {
  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-muted text-[10px] font-medium text-muted-foreground">
      {icon}{text}
    </span>
  );
}
