import { Label } from "@/components/ui/label";
import { Users } from "lucide-react";
import { AddInviteeField } from "./AddInviteeField";
import { InviteeRow } from "./InviteeRow";
import type { useCreateEvent } from "@/hooks/useCreateEvent";

type FormState = ReturnType<typeof useCreateEvent>;

interface Props {
  form: FormState;
}

export function InvitesStep({ form }: Props) {
  return (
    <div className="space-y-5">
      {/* Add Invitee */}
      <div className="space-y-2">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Add People</Label>
        <AddInviteeField onAdd={(name, phone) => form.addInvitee(name, phone, 1)} />
      </div>

      {/* Playing (Tier 1) */}
      <div className="space-y-1">
        <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
          Playing ({form.tier1Invitees.length})
        </Label>
        {form.tier1Invitees.length === 0 ? (
          <p className="text-sm text-muted-foreground py-2">No invitees yet</p>
        ) : (
          form.tier1Invitees.map(inv => (
            <InviteeRow
              key={inv.id}
              name={inv.name}
              phone={inv.phoneNumber}
              tier={1}
              onBench={() => form.setInviteeTier(inv.id, 2)}
              onRemove={() => form.removeInvitee(inv.id)}
            />
          ))
        )}
      </div>

      {/* Bench (Tier 2) */}
      {form.tier2Invitees.length > 0 && (
        <div className="space-y-1">
          <Label className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            Bench ({form.tier2Invitees.length})
          </Label>
          {form.tier2Invitees.map(inv => (
            <InviteeRow
              key={inv.id}
              name={inv.name}
              phone={inv.phoneNumber}
              tier={2}
              onPromote={() => form.setInviteeTier(inv.id, 1)}
              onRemove={() => form.removeInvitee(inv.id)}
            />
          ))}
        </div>
      )}

      {/* Empty state */}
      {form.invitees.length === 0 && (
        <div className="text-center py-8 space-y-2">
          <Users className="w-10 h-10 mx-auto text-muted-foreground/40" />
          <p className="text-sm text-muted-foreground">Add people to invite to your event</p>
          <p className="text-xs text-muted-foreground">You can skip this step and invite people later</p>
        </div>
      )}
    </div>
  );
}
