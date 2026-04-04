import { formatDistanceToNow } from "date-fns";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import type { ConversationSummary } from "@/lib/types";

interface Props {
  conversation: ConversationSummary;
  onClick: () => void;
}

export function ConversationRow({ conversation, onClick }: Props) {
  const hasUnread = (conversation.unread_count ?? 0) > 0;
  const timeAgo = conversation.last_message_at
    ? formatDistanceToNow(new Date(conversation.last_message_at), { addSuffix: true })
    : "";

  const initials = (conversation.other_display_name ?? "?")
    .split(" ")
    .map(w => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <button
      onClick={onClick}
      className="w-full flex items-center gap-3 px-4 py-3.5 text-left hover:bg-muted/40 transition-colors"
    >
      {/* Avatar with unread ring */}
      <div className={`relative shrink-0 ${hasUnread ? "ring-2 ring-primary ring-offset-2 ring-offset-background rounded-full" : ""}`}>
        <Avatar className="w-11 h-11">
          <AvatarImage src={conversation.other_avatar_url ?? undefined} />
          <AvatarFallback className="bg-muted text-muted-foreground text-sm font-bold">
            {initials}
          </AvatarFallback>
        </Avatar>
      </div>

      {/* Name + preview */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-2">
          <p className={`text-sm truncate ${hasUnread ? "font-bold text-foreground" : "font-medium text-foreground"}`}>
            {conversation.other_display_name ?? "Unknown"}
          </p>
          <span className="text-[11px] text-muted-foreground shrink-0">{timeAgo}</span>
        </div>
        <p className={`text-[13px] truncate mt-0.5 ${hasUnread ? "text-foreground font-medium" : "text-muted-foreground"}`}>
          {conversation.last_message_type === "invite"
            ? "🎲 Game Night Invite"
            : conversation.last_message_content ?? "No messages yet"}
        </p>
      </div>

      {/* Unread badge */}
      {hasUnread && (
        <div className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-[10px] font-bold flex items-center justify-center shrink-0">
          {conversation.unread_count}
        </div>
      )}
    </button>
  );
}
