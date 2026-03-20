import type { CreateStep } from "@/hooks/useCreateEvent";
import { cn } from "@/lib/utils";

const STEP_LABELS: Record<CreateStep, string> = {
  details: "Details",
  games: "Games",
  invites: "Invites",
  review: "Review",
};

const STEPS: CreateStep[] = ["details", "games", "invites", "review"];

interface Props {
  current: CreateStep;
  completed: Set<CreateStep>;
  onSelect: (step: CreateStep) => void;
  isEditing?: boolean;
}

export function StepIndicator({ current, completed, onSelect, isEditing }: Props) {
  return (
    <div className="flex gap-2 px-1">
      {STEPS.map((step, i) => {
        const isActive = step === current;
        const isDone = completed.has(step);
        const canTap = true;

        return (
          <button
            key={step}
            onClick={() => canTap && onSelect(step)}
            disabled={!canTap}
            className={cn(
              "flex-1 py-2 text-xs font-semibold rounded-lg transition-all",
              isActive
                ? "bg-primary text-primary-foreground shadow-sm"
                : isDone
                  ? "bg-primary/10 text-primary"
                  : "bg-muted text-muted-foreground",
              canTap ? "cursor-pointer active:scale-[0.97]" : "cursor-not-allowed opacity-50"
            )}
          >
            {STEP_LABELS[step]}
          </button>
        );
      })}
    </div>
  );
}
