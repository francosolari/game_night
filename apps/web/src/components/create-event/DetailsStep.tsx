import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Button } from "@/components/ui/button";
import { ChevronDown, ChevronUp, MapPin, Plus, Calendar, Clock } from "lucide-react";
import { DateTimePickerDialog } from "./DateTimePickerDialog";
import { FixedDateCard } from "./FixedDateCard";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import type { useCreateEvent } from "@/hooks/useCreateEvent";

type FormState = ReturnType<typeof useCreateEvent>;

interface Props {
  form: FormState;
}

export function DetailsStep({ form }: Props) {
  const [showPlayerDetail, setShowPlayerDetail] = useState(false);
  const [showRSVPOptions, setShowRSVPOptions] = useState(false);
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [showPollPicker, setShowPollPicker] = useState(false);

  return (
    <div className="space-y-5">
      {/* Title */}
      <div className="space-y-1.5">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Event Name</Label>
        <Input
          placeholder="Game Night at Mike's"
          value={form.title}
          onChange={(e) => form.setTitle(e.target.value)}
          className="text-base font-medium"
        />
      </div>

      {/* Schedule */}
      <div className="space-y-3">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Schedule</Label>
        <div className="flex gap-1 p-1 rounded-lg bg-muted">
          <button
            onClick={() => form.setScheduleMode("fixed")}
            className={cn(
              "flex-1 py-2 text-sm font-medium rounded-md transition-all",
              form.scheduleMode === "fixed"
                ? "bg-background text-foreground shadow-sm"
                : "text-muted-foreground"
            )}
          >
            Set a Date
          </button>
          <button
            onClick={() => form.setScheduleMode("poll")}
            className={cn(
              "flex-1 py-2 text-sm font-medium rounded-md transition-all",
              form.scheduleMode === "poll"
                ? "bg-background text-foreground shadow-sm"
                : "text-muted-foreground"
            )}
          >
            Poll Attendees
          </button>
        </div>

        {form.scheduleMode === "fixed" ? (
          <div className="space-y-2">
            {form.hasDate ? (
              <FixedDateCard
                date={form.fixedDate}
                startTime={form.fixedStartTime}
                endTime={form.hasEndTime ? form.fixedEndTime : null}
                onEdit={() => setShowDatePicker(true)}
              />
            ) : (
              <Button variant="outline" className="w-full" onClick={() => setShowDatePicker(true)}>
                <Plus className="w-4 h-4 mr-2" /> Set Date & Time
              </Button>
            )}
          </div>
        ) : (
          <div className="space-y-2">
            {form.timeOptions.map((opt, i) => (
              <FixedDateCard
                key={opt.id}
                date={new Date(opt.start_time)}
                startTime={format(new Date(opt.start_time), "HH:mm")}
                endTime={opt.end_time ? format(new Date(opt.end_time), "HH:mm") : null}
                onEdit={() => {}}
                onDelete={() => form.removeTimeOption(opt.id)}
              />
            ))}
            <Button variant="outline" className="w-full" onClick={() => setShowPollPicker(true)}>
              <Plus className="w-4 h-4 mr-2" /> Add Time Option
            </Button>
            <div className="flex items-center justify-between pt-1">
              <Label className="text-sm">Allow attendees to suggest times</Label>
              <Switch checked={form.allowTimeSuggestions} onCheckedChange={form.setAllowTimeSuggestions} />
            </div>
          </div>
        )}
      </div>

      {/* Player Count */}
      <div className="space-y-2">
        <button
          onClick={() => setShowPlayerDetail(!showPlayerDetail)}
          className="flex items-center justify-between w-full text-left"
        >
          <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground cursor-pointer">
            Player Count
          </Label>
          {showPlayerDetail ? (
            <ChevronUp className="w-4 h-4 text-muted-foreground" />
          ) : (
            <span className="text-sm text-muted-foreground">{form.minPlayers}–{form.maxPlayers || "∞"}</span>
          )}
        </button>
        {showPlayerDetail && (
          <div className="grid grid-cols-2 gap-3 pt-1">
            <div className="space-y-1">
              <Label className="text-xs">Min Players</Label>
              <div className="flex items-center gap-2">
                <Button size="icon" variant="outline" className="h-8 w-8" onClick={() => form.setMinPlayers(Math.max(1, form.minPlayers - 1))}>-</Button>
                <span className="text-sm font-medium w-6 text-center tabular-nums">{form.minPlayers}</span>
                <Button size="icon" variant="outline" className="h-8 w-8" onClick={() => form.setMinPlayers(form.minPlayers + 1)}>+</Button>
              </div>
            </div>
            <div className="space-y-1">
              <Label className="text-xs">Max Players</Label>
              <div className="flex items-center gap-2">
                <Button size="icon" variant="outline" className="h-8 w-8" onClick={() => form.setMaxPlayers(Math.max(1, (form.maxPlayers || 4) - 1))}>-</Button>
                <span className="text-sm font-medium w-6 text-center tabular-nums">{form.maxPlayers || "–"}</span>
                <Button size="icon" variant="outline" className="h-8 w-8" onClick={() => form.setMaxPlayers((form.maxPlayers || 4) + 1)}>+</Button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Location */}
      <div className="space-y-1.5">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Location</Label>
        <div className="flex items-center gap-2 p-3 rounded-xl border border-border/60 bg-card">
          <MapPin className="w-4 h-4 text-muted-foreground shrink-0" />
          <Input
            placeholder="Venue name"
            value={form.location}
            onChange={e => form.setLocation(e.target.value)}
            className="border-0 p-0 h-auto text-sm focus-visible:ring-0"
          />
        </div>
        {form.location && (
          <Input
            placeholder="Full address (optional)"
            value={form.locationAddress}
            onChange={e => form.setLocationAddress(e.target.value)}
            className="text-sm"
          />
        )}
      </div>

      {/* RSVP Options */}
      <div className="space-y-2">
        <button
          onClick={() => setShowRSVPOptions(!showRSVPOptions)}
          className="flex items-center justify-between w-full text-left"
        >
          <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground cursor-pointer">
            RSVP Options
          </Label>
          {showRSVPOptions ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
        </button>
        {showRSVPOptions && (
          <div className="space-y-3 pt-1">
            <div className="flex items-center justify-between">
              <Label className="text-sm">Allow guest invites</Label>
              <Switch checked={form.allowGuestInvites} onCheckedChange={form.setAllowGuestInvites} />
            </div>
            <div className="flex items-center justify-between">
              <Label className="text-sm">Allow "Maybe" RSVP</Label>
              <Switch checked={form.allowMaybeRSVP} onCheckedChange={form.setAllowMaybeRSVP} />
            </div>
            <div className="flex items-center justify-between">
              <Label className="text-sm">Plus-one limit</Label>
              <div className="flex items-center gap-2">
                <Button size="icon" variant="outline" className="h-7 w-7" onClick={() => form.setPlusOneLimit(Math.max(0, form.plusOneLimit - 1))}>-</Button>
                <span className="text-sm w-4 text-center tabular-nums">{form.plusOneLimit}</span>
                <Button size="icon" variant="outline" className="h-7 w-7" onClick={() => form.setPlusOneLimit(Math.min(9, form.plusOneLimit + 1))}>+</Button>
              </div>
            </div>
            {form.plusOneLimit > 0 && (
              <div className="flex items-center justify-between">
                <Label className="text-sm">Require plus-one names</Label>
                <Switch checked={form.requirePlusOneNames} onCheckedChange={form.setRequirePlusOneNames} />
              </div>
            )}
          </div>
        )}
      </div>

      {/* Privacy */}
      <div className="space-y-2">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Privacy</Label>
        <div className="flex gap-1 p-1 rounded-lg bg-muted">
          <button
            onClick={() => form.setVisibility("private")}
            className={cn(
              "flex-1 py-2 text-sm font-medium rounded-md transition-all",
              form.visibility === "private" ? "bg-background text-foreground shadow-sm" : "text-muted-foreground"
            )}
          >
            Private
          </button>
          <button
            onClick={() => form.setVisibility("public")}
            className={cn(
              "flex-1 py-2 text-sm font-medium rounded-md transition-all",
              form.visibility === "public" ? "bg-background text-foreground shadow-sm" : "text-muted-foreground"
            )}
          >
            Public
          </button>
        </div>
      </div>

      {/* Description */}
      <div className="space-y-1.5">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Description</Label>
        <Textarea
          placeholder="Tell your guests what to expect…"
          value={form.description}
          onChange={e => form.setDescription(e.target.value)}
          rows={3}
          className="text-sm resize-none"
        />
      </div>

      {/* Dialogs */}
      <DateTimePickerDialog
        open={showDatePicker}
        onOpenChange={setShowDatePicker}
        initialDate={form.fixedDate}
        initialStartTime={form.fixedStartTime}
        initialEndTime={form.hasEndTime ? form.fixedEndTime : null}
        title="Set Date & Time"
        onSave={(date, startTime, endTime) => {
          form.setFixedDate(date);
          form.setFixedStartTime(startTime);
          form.setHasDate(true);
          if (endTime) {
            form.setFixedEndTime(endTime);
            form.setHasEndTime(true);
          } else {
            form.setHasEndTime(false);
          }
        }}
      />

      <DateTimePickerDialog
        open={showPollPicker}
        onOpenChange={setShowPollPicker}
        title="Add Time Option"
        onSave={(date, startTime, endTime) => {
          const dateStr = date.toISOString().split("T")[0];
          const startISO = new Date(`${dateStr}T${startTime}:00`).toISOString();
          const endISO = endTime ? new Date(`${dateStr}T${endTime}:00`).toISOString() : null;
          form.addTimeOption(dateStr, startISO, endISO);
        }}
      />
    </div>
  );
}
