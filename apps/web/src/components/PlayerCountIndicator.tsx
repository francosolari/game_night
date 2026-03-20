import { useMemo } from "react";
import { Check, User } from "lucide-react";

export type PlayerCountSize = "compact" | "standard" | "expanded";

interface Props {
  confirmedCount: number;
  minPlayers: number;
  maxPlayers?: number | null;
  size?: PlayerCountSize;
  className?: string;
}

export function PlayerCountIndicator({
  confirmedCount,
  minPlayers,
  maxPlayers,
  size = "standard",
  className = "",
}: Props) {
  const effectiveMax = maxPlayers ?? minPlayers;
  const hasQuorum = confirmedCount >= minPlayers;
  const isFull = confirmedCount >= effectiveMax;

  const statusColor = useMemo(() => {
    if (isFull) return { text: "text-muted-foreground", bg: "bg-muted-foreground", hex: "hsl(var(--muted-foreground))" };
    if (hasQuorum) return { text: "text-green-500", bg: "bg-green-500", hex: "#22c55e" };
    return { text: "text-amber-500", bg: "bg-amber-500", hex: "#f59e0b" };
  }, [isFull, hasQuorum]);

  const statusLabel = useMemo(() => {
    if (!hasQuorum) {
      const needed = minPlayers - confirmedCount;
      return { text: `${needed} more needed`, color: "text-amber-500" };
    }
    if (isFull) return { text: "Full", color: "text-muted-foreground" };
    const spots = effectiveMax - confirmedCount;
    return { text: `${spots} spot${spots === 1 ? "" : "s"} left`, color: "text-green-500" };
  }, [hasQuorum, isFull, minPlayers, confirmedCount, effectiveMax]);

  if (effectiveMax <= 0) return null;

  const iconSize = size === "compact" ? "w-[9px] h-[9px]" : size === "expanded" ? "w-3 h-3" : "w-[10px] h-[10px]";
  const countSize = size === "compact" ? "text-xs" : size === "expanded" ? "text-base" : "text-sm";
  const barWidth = size === "compact" ? "w-11" : size === "expanded" ? "w-16" : "w-[50px]";
  const showLabel = size !== "compact";

  return (
    <div className={`flex flex-col items-end gap-0.5 ${className}`}>
      {/* Count row */}
      <div className="flex items-center gap-1">
        {hasQuorum ? (
          <Check className={`${iconSize} ${statusColor.text}`} strokeWidth={3} />
        ) : (
          <User className={`${iconSize} ${statusColor.text}`} />
        )}
        <span className={`${countSize} font-semibold tabular-nums ${statusColor.text}`}>
          {confirmedCount}
        </span>
        <span className="text-[10px] text-muted-foreground">
          of {effectiveMax}
        </span>
      </div>

      {/* Segmented bar */}
      <div className={`${barWidth} h-1 flex gap-[1.5px]`}>
        {Array.from({ length: effectiveMax }, (_, i) => {
          let opacity: string;
          if (i < confirmedCount) {
            opacity = "opacity-100";
          } else if (i < minPlayers) {
            opacity = "opacity-45";
          } else {
            opacity = "opacity-20";
          }

          const bgColor = i < minPlayers || i < confirmedCount
            ? statusColor.bg
            : "bg-muted-foreground";

          return (
            <div
              key={i}
              className={`flex-1 rounded-[1px] ${bgColor} ${opacity}`}
              style={{ minWidth: "2px" }}
            />
          );
        })}
      </div>

      {/* Status label */}
      {showLabel && (
        <span className={`text-[10px] font-medium ${statusLabel.color}`}>
          {statusLabel.text}
        </span>
      )}
    </div>
  );
}
