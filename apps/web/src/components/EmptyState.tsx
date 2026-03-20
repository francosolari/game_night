import { Dice5, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";

interface EmptyStateProps {
  onCreateEvent: () => void;
}

export function EmptyState({ onCreateEvent }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-20 px-6 text-center">
      <div className="w-16 h-16 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
        <Dice5 className="w-8 h-8 text-primary" />
      </div>
      <h2 className="text-xl font-bold text-foreground mb-2">No Game Nights Yet</h2>
      <p className="text-sm text-muted-foreground mb-6 max-w-[260px]">
        Create your first game night and invite friends to play!
      </p>
      <Button onClick={onCreateEvent} className="gap-2">
        <Plus className="w-4 h-4" />
        Create Game Night
      </Button>
    </div>
  );
}
