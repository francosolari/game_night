import { format } from "date-fns";
import { Calendar, Clock, Trash2 } from "lucide-react";

interface Props {
  date: Date;
  startTime: string;
  endTime?: string | null;
  onEdit: () => void;
  onDelete?: () => void;
}

export function FixedDateCard({ date, startTime, endTime, onEdit, onDelete }: Props) {
  const timeLabel = endTime ? `${startTime} – ${endTime}` : startTime;

  return (
    <button
      onClick={onEdit}
      className="w-full flex items-center gap-3 p-3 rounded-xl bg-card border border-border/60 hover:border-primary/30 transition-colors text-left active:scale-[0.98]"
    >
      <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
        <Calendar className="w-5 h-5 text-primary" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground">{format(date, "EEEE, MMM d, yyyy")}</p>
        <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
          <Clock className="w-3 h-3" /> {timeLabel}
        </p>
      </div>
      {onDelete && (
        <button
          onClick={(e) => { e.stopPropagation(); onDelete(); }}
          className="p-1.5 rounded-lg hover:bg-destructive/10 transition-colors"
        >
          <Trash2 className="w-4 h-4 text-destructive" />
        </button>
      )}
    </button>
  );
}
