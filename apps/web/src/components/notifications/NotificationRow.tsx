import { formatDistanceToNow } from "date-fns";
import type { AppNotification, NotificationType } from "@/lib/types";

const typeConfig: Record<NotificationType, { icon: string; colorClass: string }> = {
  invite_received: { icon: "✉️", colorClass: "bg-primary/15 text-primary" },
  rsvp_update: { icon: "✅", colorClass: "bg-green-500/15 text-green-600" },
  group_invite: { icon: "👥", colorClass: "bg-blue-500/15 text-blue-600" },
  time_confirmed: { icon: "📅", colorClass: "bg-accent/15 text-accent" },
  bench_promoted: { icon: "🎉", colorClass: "bg-amber-500/15 text-amber-600" },
  dm_received: { icon: "💬", colorClass: "bg-blue-500/15 text-blue-600" },
  text_blast: { icon: "📢", colorClass: "bg-purple-500/15 text-purple-600" },
  game_confirmed: { icon: "🎲", colorClass: "bg-primary/15 text-primary" },
  event_cancelled: { icon: "❌", colorClass: "bg-destructive/15 text-destructive" },
};

interface Props {
  notification: AppNotification;
  onClick?: () => void;
}

export function NotificationRow({ notification, onClick }: Props) {
  const config = typeConfig[notification.type] ?? typeConfig.invite_received;
  const timeAgo = formatDistanceToNow(new Date(notification.created_at), { addSuffix: true });

  return (
    <button
      onClick={onClick}
      className="w-full flex items-start gap-3 px-4 py-3.5 text-left hover:bg-muted/40 transition-colors"
    >
      {/* Icon circle */}
      <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 text-base ${config.colorClass}`}>
        {config.icon}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-foreground leading-snug line-clamp-1">
          {notification.title}
        </p>
        {notification.body && (
          <p className="text-[13px] text-muted-foreground leading-snug mt-0.5 line-clamp-2">
            {notification.body}
          </p>
        )}
        <p className="text-[11px] text-muted-foreground/70 mt-1">{timeAgo}</p>
      </div>

      {/* Unread dot */}
      {!notification.read_at && (
        <div className="w-2.5 h-2.5 rounded-full bg-primary mt-1.5 shrink-0" />
      )}
    </button>
  );
}
