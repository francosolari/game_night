import { Users, Clock, Scale, Star, Hash } from "lucide-react";
import { cn } from "@/lib/utils";

export interface InfoRowData {
  icon: string;
  label: string;
  value: string;
  detail?: string;
  detailColor?: string;
}

const iconMap: Record<string, React.ReactNode> = {
  "person.2.fill": <Users className="w-4 h-4" />,
  "clock.fill": <Clock className="w-4 h-4" />,
  "scalemass.fill": <Scale className="w-4 h-4" />,
  "star.fill": <Star className="w-4 h-4" />,
  "number.circle": <Hash className="w-4 h-4" />,
};

export function InfoRowGroup({ rows }: { rows: InfoRowData[] }) {
  if (rows.length === 0) return null;

  return (
    <div className="rounded-xl bg-card overflow-hidden">
      {rows.map((row, i) => (
        <div key={row.label}>
          <div className="flex items-center gap-3 px-4 py-3">
            <span className="text-primary w-7 flex justify-center shrink-0">
              {iconMap[row.icon] || <span className="text-sm">•</span>}
            </span>
            <span className={cn(
              "font-bold text-sm",
              row.label === "Weight" && row.detailColor ? row.detailColor : "text-foreground"
            )}>
              {row.value}
            </span>
            {row.detail && (
              <span className={cn("text-xs", row.detailColor || "text-muted-foreground")}>
                {row.detail}
              </span>
            )}
          </div>
          {i < rows.length - 1 && (
            <div className="border-t border-border ml-[3.75rem]" />
          )}
        </div>
      ))}
    </div>
  );
}
