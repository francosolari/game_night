import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Shuffle, MapPin, Users, Calendar, Dice5 } from "lucide-react";
import { GenerativeEventCover } from "@/components/GenerativeEventCover";
import { format } from "date-fns";
import type { useCreateEvent } from "@/hooks/useCreateEvent";

type FormState = ReturnType<typeof useCreateEvent>;

interface Props {
  form: FormState;
}

export function ReviewStep({ form }: Props) {
  const primaryGame = form.selectedGames.find(g => g.is_primary);

  const dateLabel = (() => {
    if (form.scheduleMode === "fixed" && form.hasDate) {
      const t = form.fixedStartTime;
      return `${format(form.fixedDate, "EEE, MMM d")} at ${t}`;
    }
    if (form.scheduleMode === "poll" && form.timeOptions.length > 0) {
      return `${form.timeOptions.length} time option${form.timeOptions.length > 1 ? "s" : ""} (poll)`;
    }
    return "No date set";
  })();

  return (
    <div className="space-y-5">
      {/* Cover Preview */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Cover Art
          </Label>
          <Button
            variant="ghost"
            size="sm"
            className="text-xs h-7 gap-1"
            onClick={() => form.setCoverVariant(form.coverVariant + 1)}
          >
            <Shuffle className="w-3.5 h-3.5" /> Shuffle
          </Button>
        </div>
        <div className="rounded-xl overflow-hidden aspect-[2/1]">
          <GenerativeEventCover
            title={form.title || "Untitled Event"}
            eventId={form.previewEventId}
            variant={form.coverVariant}
            className="w-full h-full"
          />
        </div>
      </div>

      {/* Summary Card */}
      <div className="rounded-xl bg-card border border-border/60 p-4 space-y-3">
        <h3 className="text-lg font-bold text-foreground">{form.title || "Untitled Event"}</h3>

        {/* Date */}
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Calendar className="w-4 h-4 shrink-0" />
          <span>{dateLabel}</span>
        </div>

        {/* Location */}
        {form.location && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <MapPin className="w-4 h-4 shrink-0" />
            <span>{form.location}</span>
          </div>
        )}

        {/* Games */}
        {form.selectedGames.length > 0 && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Dice5 className="w-4 h-4 shrink-0" />
            <span>
              {form.selectedGames.map(g => g.game?.name || "Unknown").join(", ")}
            </span>
          </div>
        )}

        {/* Invitees */}
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Users className="w-4 h-4 shrink-0" />
          <span>
            {form.invitees.length === 0
              ? "No invitees yet"
              : `${form.invitees.length} invitee${form.invitees.length > 1 ? "s" : ""}`}
          </span>
        </div>

        {/* Privacy */}
        <div className="flex items-center gap-2">
          <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground capitalize">
            {form.visibility}
          </span>
          {form.scheduleMode === "poll" && (
            <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground">
              Time Poll
            </span>
          )}
        </div>
      </div>

      {/* Error */}
      {form.error && (
        <div className="rounded-xl bg-destructive/10 border border-destructive/20 p-3">
          <p className="text-sm text-destructive">{form.error}</p>
        </div>
      )}
    </div>
  );
}
