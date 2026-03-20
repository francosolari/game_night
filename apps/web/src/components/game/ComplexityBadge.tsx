import { cn } from "@/lib/utils";
import { complexityLabel, complexityColorClass } from "@/lib/types";

interface Props {
  weight: number;
  className?: string;
  showValue?: boolean;
}

export function ComplexityBadge({ weight, className, showValue = false }: Props) {
  const label = complexityLabel(weight);
  const colorCls = complexityColorClass(weight);

  return (
    <span className={cn("inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold", colorCls, className)}>
      <span className="flex gap-0.5">
        {[1, 2, 3, 4, 5].map(i => (
          <span key={i} className={cn("w-1.5 h-1.5 rounded-full", i <= Math.round(weight) ? "bg-current" : "bg-current/20")} />
        ))}
      </span>
      {showValue && <span className="tabular-nums">{weight.toFixed(2)}</span>}
      {label}
    </span>
  );
}
