import { useState } from "react";
import { Check, X, HelpCircle, CheckCircle } from "lucide-react";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import type { GameEvent, Invite, InviteStatusType, TimeOption } from "@/lib/types";

interface Props {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  event: GameEvent;
  currentStatus: InviteStatusType | null;
  isSending: boolean;
  pollVotes: Record<string, string>;
  onPollVoteChange: (optionId: string, voteType: string) => void;
  onSubmit: (status: string, votes: { time_option_id: string; vote_type: string }[]) => Promise<void>;
}

type VoteType = "yes" | "maybe" | "no";

export function RSVPDialog({ open, onOpenChange, event, currentStatus, isSending, pollVotes, onPollVoteChange, onSubmit }: Props) {
  const [selectedStatus, setSelectedStatus] = useState<string | null>(
    currentStatus && currentStatus !== "pending" ? currentStatus : null
  );

  const isPollMode = event.schedule_mode === "poll" && event.time_options.length > 1;
  const canSubmit = selectedStatus !== null && !isSending;

  const handleSubmit = async () => {
    if (!selectedStatus) return;
    const votes = selectedStatus === "declined"
      ? []
      : Object.entries(pollVotes).map(([id, type]) => ({ time_option_id: id, vote_type: type }));
    await onSubmit(selectedStatus, votes);
    onOpenChange(false);
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="max-h-[85vh] rounded-t-2xl p-0 bg-background">
        <div className="overflow-y-auto max-h-[calc(85vh-80px)] px-5 pt-6 pb-4 space-y-6">
          <SheetHeader className="text-left">
            <SheetTitle className="text-xl font-bold text-foreground">Are you going?</SheetTitle>
          </SheetHeader>

          {/* RSVP Options */}
          <div className="space-y-2.5">
            <RSVPOption
              title="Going"
              icon={<CheckCircle className="w-5 h-5" />}
              colorClass="bg-green-500"
              fieldColor="bg-green-500/10 border-green-500/30"
              isSelected={selectedStatus === "accepted"}
              onSelect={() => setSelectedStatus("accepted")}
            />
            <RSVPOption
              title="Maybe"
              icon={<HelpCircle className="w-5 h-5" />}
              colorClass="bg-amber-500"
              fieldColor="bg-amber-500/10 border-amber-500/30"
              isSelected={selectedStatus === "maybe"}
              onSelect={() => setSelectedStatus("maybe")}
            />
            <RSVPOption
              title="Can't Go"
              icon={<X className="w-5 h-5" />}
              colorClass="bg-red-500"
              fieldColor="bg-red-500/10 border-red-500/30"
              isSelected={selectedStatus === "declined"}
              onSelect={() => setSelectedStatus("declined")}
            />
          </div>

          {/* Time Poll Voting */}
          {isPollMode && selectedStatus && selectedStatus !== "declined" && (
            <div className="space-y-3">
              <h3 className="text-lg font-bold text-foreground">Find a Time</h3>
              <p className="text-sm text-muted-foreground">Vote on the times that work for you:</p>
              <div className="space-y-2">
                {event.time_options.map(option => (
                  <TimePollRow
                    key={option.id}
                    option={option}
                    vote={(pollVotes[option.id] as VoteType) || null}
                    onVote={(type) => onPollVoteChange(option.id, type)}
                  />
                ))}
              </div>
              <p className="text-xs text-muted-foreground">When the host picks a time, your RSVP will auto-update.</p>
            </div>
          )}
        </div>

        {/* Bottom submit */}
        <div className="border-t border-border px-5 py-3 bg-card">
          <Button
            onClick={handleSubmit}
            disabled={!canSubmit}
            className="w-full py-3 font-semibold"
          >
            {isSending ? "Sending..." : currentStatus === null || currentStatus === "pending" ? "Confirm RSVP" : "Update RSVP"}
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  );
}

function RSVPOption({ title, icon, colorClass, fieldColor, isSelected, onSelect }: {
  title: string;
  icon: React.ReactNode;
  colorClass: string;
  fieldColor: string;
  isSelected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      onClick={onSelect}
      className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl border transition-all active:scale-[0.98] ${
        isSelected
          ? `${colorClass} text-white border-transparent`
          : `bg-card ${fieldColor} text-foreground`
      }`}
    >
      <span className={isSelected ? "text-white" : ""}>{icon}</span>
      <span className="font-semibold flex-1 text-left">{title}</span>
      {isSelected && <Check className="w-4 h-4 font-bold" />}
    </button>
  );
}

function TimePollRow({ option, vote, onVote }: {
  option: TimeOption;
  vote: VoteType | null;
  onVote: (type: VoteType) => void;
}) {
  const d = new Date(option.start_time);
  const dateStr = d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
  const timeStr = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });

  return (
    <div className="flex items-center justify-between p-3 rounded-lg bg-card border border-border">
      <div>
        <p className="text-sm font-semibold text-foreground">{dateStr}</p>
        <p className="text-xs text-muted-foreground">{timeStr}</p>
      </div>
      <div className="flex gap-1.5">
        {(["yes", "maybe", "no"] as VoteType[]).map(type => {
          const selected = vote === type;
          const colors: Record<VoteType, string> = {
            yes: selected ? "bg-green-500 text-white" : "bg-green-500/10 text-green-500",
            maybe: selected ? "bg-amber-500 text-white" : "bg-amber-500/10 text-amber-500",
            no: selected ? "bg-red-500 text-white" : "bg-red-500/10 text-red-500",
          };
          const icons: Record<VoteType, string> = { yes: "✓", maybe: "?", no: "✕" };
          return (
            <button
              key={type}
              onClick={() => onVote(type)}
              className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all active:scale-90 ${colors[type]}`}
            >
              {icons[type]}
            </button>
          );
        })}
      </div>
    </div>
  );
}
