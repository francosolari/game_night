import { Dice5, Clock, Brain, ChevronRight, CheckCircle } from "lucide-react";
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
  if (event.games.length === 0) return null;

  const isVotingMode = event.allow_game_voting && event.games.length > 1;

  if (isVotingMode) {
    return (
      <div className="space-y-3">
        <SectionLabel title="What We're Playing" />

        {/* Quorum warning */}
        {event.min_players > 0 && (
          <QuorumWarning event={event} />
        )}

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
                <div className="flex flex-col items-center gap-2">
                  {game.image_url || game.thumbnail_url ? (
                    <img
                      src={game.image_url || game.thumbnail_url || ""}
                      alt={game.name}
                      className="w-16 h-16 rounded-lg object-cover"
                    />
                  ) : (
                    <div className="w-16 h-16 rounded-lg bg-muted flex items-center justify-center">
                      <Dice5 className="w-6 h-6 text-muted-foreground" />
                    </div>
                  )}
                  <div className="text-center">
                    <p className="text-xs font-semibold text-foreground line-clamp-2">{game.name}</p>
                    <p className="text-[9px] text-muted-foreground">
                      {game.min_playtime}–{game.max_playtime}m · {game.complexity.toFixed(1)}⚖️
                    </p>
                  </div>
                </div>

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

        {/* Primary game */}
        <div className="flex items-center gap-3">
          {primaryGame.image_url || primaryGame.thumbnail_url ? (
            <img
              src={primaryGame.image_url || primaryGame.thumbnail_url || ""}
              alt={primaryGame.name}
              className="w-14 h-14 rounded-lg object-cover shrink-0"
            />
          ) : (
            <div className="w-14 h-14 rounded-lg bg-muted flex items-center justify-center shrink-0">
              <Dice5 className="w-5 h-5 text-muted-foreground" />
            </div>
          )}

          <div className="flex-1 min-w-0 space-y-1.5">
            <p className="font-bold text-foreground">{primaryGame.name}</p>
            <div className="flex gap-1.5">
              <Pill icon={<Clock className="w-[9px] h-[9px]" />} text={`${primaryGame.min_playtime}–${primaryGame.max_playtime}m`} />
              {primaryGame.complexity > 0 && (
                <Pill icon={<Brain className="w-[9px] h-[9px]" />} text={`${primaryGame.complexity.toFixed(1)}/5`} />
              )}
            </div>
          </div>

          <ChevronRight className="w-3 h-3 text-muted-foreground shrink-0" />
        </div>

        {/* Other games */}
        {otherGames.length > 0 && (
          <>
            <div className="border-t border-border" />
            <div className="flex items-center gap-2 overflow-x-auto scrollbar-hide">
              <span className="text-[10px] text-muted-foreground shrink-0">Also playing</span>
              {otherGames.map(eg => eg.game && (
                <div key={eg.id} className="flex items-center gap-1 shrink-0">
                  {eg.game.thumbnail_url ? (
                    <img src={eg.game.thumbnail_url} alt="" className="w-5 h-5 rounded object-cover" />
                  ) : (
                    <Dice5 className="w-3.5 h-3.5 text-muted-foreground" />
                  )}
                  <span className="text-xs font-bold text-muted-foreground">{eg.game.name}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function SectionLabel({ title }: { title: string }) {
  return <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">{title}</h3>;
}

function QuorumWarning({ event }: { event: GameEvent }) {
  return null; // placeholder — would need invite summary count
}

function VoteDot({ color, count }: { color: string; count: number }) {
  return (
    <div className="flex items-center gap-0.5">
      <div className={`w-[5px] h-[5px] rounded-full ${color}`} />
      <span className="text-[10px] font-medium text-muted-foreground">{count}</span>
    </div>
  );
}

function Pill({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-muted text-[10px] font-medium text-muted-foreground">
      {icon}{text}
    </span>
  );
}
