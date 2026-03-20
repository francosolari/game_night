import { MoreHorizontal, Trash2, User } from "lucide-react";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { GroupMember } from "@/lib/groupTypes";

interface MemberRowProps {
  member: GroupMember;
  onRemove?: (memberId: string) => void;
  canRemove?: boolean;
}

export function MemberRow({ member, onRemove, canRemove }: MemberRowProps) {
  return (
    <div className="flex items-center gap-3 py-2.5 px-1">
      <div className="w-9 h-9 rounded-full bg-muted flex items-center justify-center shrink-0">
        <User className="w-4 h-4 text-muted-foreground" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[13px] font-semibold text-foreground truncate">
          {member.display_name || "Unknown"}
        </p>
        <p className="text-[11px] text-muted-foreground truncate">
          {member.phone_number}
        </p>
      </div>
      {canRemove && onRemove && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="p-1.5 rounded-lg hover:bg-muted/80 transition-colors">
              <MoreHorizontal className="w-4 h-4 text-muted-foreground" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => onRemove(member.id)} className="text-destructive focus:text-destructive">
              <Trash2 className="w-4 h-4 mr-2" />
              Remove
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      )}
    </div>
  );
}
