import { useState, useMemo } from "react";
import { UserPlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MemberRow } from "./MemberRow";
import { ContactListSheet } from "./ContactListSheet";
import { addGroupMember } from "@/lib/groupQueries";
import { toast } from "sonner";
import type { GameGroup } from "@/lib/groupTypes";

interface MembersTabProps {
  group: GameGroup;
  onMemberRemoved: (memberId: string) => void;
  onMemberAdded: () => void;
}

export function MembersTab({ group, onMemberRemoved, onMemberAdded }: MembersTabProps) {
  const [showContacts, setShowContacts] = useState(false);

  const excludedPhones = useMemo(
    () => new Set(group.members.map(m => m.phone_number)),
    [group.members]
  );

  const handleSelect = async (contacts: { name: string; phone_number: string }[]) => {
    let added = 0;
    for (const c of contacts) {
      try {
        await addGroupMember(group.id, { phone_number: c.phone_number, display_name: c.name });
        added++;
      } catch {
        // skip dupes
      }
    }
    if (added > 0) {
      toast.success(`Added ${added} ${added === 1 ? "member" : "members"}`);
      onMemberAdded();
    }
  };

  return (
    <div className="space-y-4">
      <Button variant="outline" size="sm" onClick={() => setShowContacts(true)} className="w-full gap-2">
        <UserPlus className="w-4 h-4" />
        Add Members
      </Button>

      <div className="divide-y divide-border/50">
        {group.members.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">No members yet</p>
        ) : (
          group.members.map(m => (
            <MemberRow key={m.id} member={m} onRemove={onMemberRemoved} canRemove />
          ))
        )}
      </div>

      <ContactListSheet
        open={showContacts}
        onOpenChange={setShowContacts}
        excludedPhones={excludedPhones}
        onSelect={handleSelect}
      />
    </div>
  );
}
