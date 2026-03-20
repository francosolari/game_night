import { useState } from "react";
import { UserPlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MemberRow } from "./MemberRow";
import { AddMemberDialog } from "./AddMemberDialog";
import type { GameGroup } from "@/lib/groupTypes";

interface MembersTabProps {
  group: GameGroup;
  onMemberRemoved: (memberId: string) => void;
  onMemberAdded: () => void;
}

export function MembersTab({ group, onMemberRemoved, onMemberAdded }: MembersTabProps) {
  const [showAdd, setShowAdd] = useState(false);

  return (
    <div className="space-y-4">
      <Button variant="outline" size="sm" onClick={() => setShowAdd(true)} className="w-full gap-2">
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

      <AddMemberDialog
        open={showAdd}
        onOpenChange={setShowAdd}
        groupId={group.id}
        onAdded={onMemberAdded}
      />
    </div>
  );
}
