import { formatDistanceToNow } from "date-fns";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { InviteMessageCard } from "./InviteMessageCard";
import type { DirectMessage } from "@/lib/types";

interface Props {
  message: DirectMessage;
  isMine: boolean;
  onInviteTap?: (eventId: string) => void;
}

export function MessageBubble({ message, isMine, onInviteTap }: Props) {
  if (message.message_type === "system") {
    return (
      <div className="flex justify-center py-1.5">
        <p className="text-[11px] text-muted-foreground/70 font-medium px-3 py-1 bg-muted/40 rounded-full">
          {message.content}
        </p>
      </div>
    );
  }

  if (message.message_type === "invite" && message.metadata) {
    return (
      <div className={`flex ${isMine ? "justify-end" : "justify-start"} mb-2`}>
        <div className={`max-w-[85%] ${isMine ? "items-end" : "items-start"}`}>
          <InviteMessageCard
            metadata={message.metadata}
            onTap={onInviteTap ? () => onInviteTap(message.metadata!.event_id!) : undefined}
          />
          <p className="text-[10px] text-muted-foreground/60 mt-1 px-1">
            {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
          </p>
        </div>
      </div>
    );
  }

  const senderInitial = message.sender?.display_name?.[0]?.toUpperCase() ?? "?";

  return (
    <div className={`flex ${isMine ? "justify-end" : "justify-start"} mb-2 gap-2`}>
      {!isMine && (
        <Avatar className="w-7 h-7 mt-1 shrink-0">
          <AvatarImage src={message.sender?.avatar_url ?? undefined} />
          <AvatarFallback className="bg-muted text-[10px] font-bold">{senderInitial}</AvatarFallback>
        </Avatar>
      )}
      <div className="max-w-[75%]">
        <div
          className={`px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed ${
            isMine
              ? "bg-primary text-primary-foreground rounded-br-md"
              : "bg-card border border-border/60 text-foreground rounded-bl-md"
          }`}
        >
          {message.content}
        </div>
        <p className={`text-[10px] text-muted-foreground/60 mt-1 ${isMine ? "text-right" : "text-left"} px-1`}>
          {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
        </p>
      </div>
    </div>
  );
}
