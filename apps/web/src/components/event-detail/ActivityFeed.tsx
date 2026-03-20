import { useState } from "react";
import { Lock, Pin, Megaphone, Send, Reply, CalendarCheck, Gamepad2 } from "lucide-react";
import type { ActivityFeedItem } from "@/lib/types";

interface Props {
  feed: ActivityFeedItem[];
  canSee: boolean;
  isHost: boolean;
  isPosting: boolean;
  onPostComment: (content: string, parentId?: string | null) => Promise<void>;
  onPostAnnouncement: (content: string) => Promise<void>;
  onTogglePin: (itemId: string, isPinned: boolean) => Promise<void>;
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "now";
  if (mins < 60) return `${mins}m`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h`;
  const days = Math.floor(hrs / 24);
  return `${days}d`;
}

export function ActivityFeed({ feed, canSee, isHost, isPosting, onPostComment, onPostAnnouncement, onTogglePin }: Props) {
  const [text, setText] = useState("");
  const [isAnnouncement, setIsAnnouncement] = useState(false);
  const [replyingTo, setReplyingTo] = useState<ActivityFeedItem | null>(null);

  // Filter RSVP updates to only show accepted/maybe
  const visibleItems = feed.filter(item => {
    if (item.type === "rsvp_update") return item.content === "accepted" || item.content === "maybe";
    return true;
  });

  // Group consecutive same-status RSVP updates
  const groupedItems = groupFeedItems(visibleItems);

  const handleSend = async () => {
    const content = text.trim();
    if (!content) return;
    setText("");
    if (isAnnouncement && isHost) {
      await onPostAnnouncement(content);
      setIsAnnouncement(false);
    } else {
      await onPostComment(content, replyingTo?.id);
      setReplyingTo(null);
    }
  };

  return (
    <div className="rounded-xl bg-card border border-border p-4 space-y-3">
      <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">Activity</h3>

      {!canSee ? (
        <div className="flex flex-col items-center gap-2 py-8">
          <Lock className="w-6 h-6 text-muted-foreground" />
          <p className="text-sm text-muted-foreground text-center">RSVP to see comments & updates</p>
        </div>
      ) : (
        <>
          {/* Feed items */}
          <div className="space-y-0">
            {groupedItems.map((item, idx) => {
              if (item._grouped) {
                return <GroupedRSVPRow key={idx} items={item._groupedItems!} status={item._groupedStatus!} />;
              }
              if (item.is_pinned) {
                return <PinnedItemRow key={item.id} item={item} isHost={isHost} onTogglePin={onTogglePin} />;
              }
              if (item.type === "rsvp_update") {
                return <RSVPUpdateRow key={item.id} item={item} />;
              }
              if (item.type === "date_confirmed" || item.type === "game_confirmed") {
                return <SystemEventRow key={item.id} item={item} />;
              }
              return (
                <CommentRow
                  key={item.id}
                  item={item}
                  isHost={isHost}
                  onReply={() => setReplyingTo(item)}
                  onTogglePin={onTogglePin}
                />
              );
            })}
          </div>

          {/* Comment input */}
          <div className="space-y-2">
            {replyingTo && (
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Reply className="w-3 h-3" />
                <span>Replying to {replyingTo.user?.display_name || "someone"}</span>
                <button onClick={() => setReplyingTo(null)} className="text-primary font-medium">Cancel</button>
              </div>
            )}

            <div className="flex gap-2 items-end">
              {isHost && (
                <button
                  onClick={() => setIsAnnouncement(!isAnnouncement)}
                  className={`shrink-0 w-8 h-8 rounded-full flex items-center justify-center transition-colors ${
                    isAnnouncement ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
                  }`}
                  title="Toggle announcement"
                >
                  <Megaphone className="w-3.5 h-3.5" />
                </button>
              )}

              <input
                type="text"
                value={text}
                onChange={e => setText(e.target.value)}
                onKeyDown={e => e.key === "Enter" && handleSend()}
                placeholder={isAnnouncement ? "Post an announcement..." : "Write a comment..."}
                className="flex-1 bg-muted rounded-lg px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground outline-none"
              />

              <button
                onClick={handleSend}
                disabled={!text.trim() || isPosting}
                className="shrink-0 w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center disabled:opacity-40 active:scale-90 transition-transform"
              >
                <Send className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// ─── Sub-components ───

function PinnedItemRow({ item, isHost, onTogglePin }: { item: ActivityFeedItem; isHost: boolean; onTogglePin: (id: string, pinned: boolean) => Promise<void> }) {
  return (
    <div className="border-l-2 border-primary bg-primary/5 rounded-r-lg p-3 my-1">
      <div className="flex items-center gap-1 text-primary mb-1">
        <Pin className="w-2 h-2" />
        <span className="text-[9px] font-bold tracking-wide">PINNED</span>
      </div>
      <div className="flex items-start gap-2">
        <Avatar name={item.user?.display_name} url={item.user?.avatar_url} size={32} />
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <span className="text-sm font-semibold text-foreground">{item.user?.display_name || "Unknown"}</span>
            {item.type === "announcement" && <HostBadge />}
            <span className="text-[10px] text-muted-foreground">{relativeTime(item.created_at)}</span>
          </div>
          {item.content && <p className="text-sm text-muted-foreground leading-relaxed">{item.content}</p>}
        </div>
        {isHost && (
          <button onClick={() => onTogglePin(item.id, false)} className="text-[10px] text-muted-foreground hover:text-foreground">
            Unpin
          </button>
        )}
      </div>
    </div>
  );
}

function RSVPUpdateRow({ item }: { item: ActivityFeedItem }) {
  const statusText = item.content === "accepted" ? "is going" : item.content === "maybe" ? "changed to maybe" : "updated RSVP";
  const dotColor = item.content === "accepted" ? "bg-green-500" : item.content === "maybe" ? "bg-amber-500" : "bg-muted-foreground";

  return (
    <div className="flex items-center gap-2 px-2 py-1.5">
      <Avatar name={item.user?.display_name} url={item.user?.avatar_url} size={20} />
      <p className="text-xs text-muted-foreground flex-1">
        <span className="font-medium text-foreground/80">{item.user?.display_name || "Someone"}</span> {statusText}
      </p>
      <span className={`w-1.5 h-1.5 rounded-full ${dotColor}`} />
      <span className="text-[10px] text-muted-foreground/60">{relativeTime(item.created_at)}</span>
    </div>
  );
}

function GroupedRSVPRow({ items, status }: { items: ActivityFeedItem[]; status: string }) {
  const names = items.map(i => i.user?.display_name || "Someone");
  const display = names.length <= 2
    ? names.join(" and ")
    : `${names.slice(0, 2).join(", ")}, and ${names.length - 2} other${names.length - 2 === 1 ? "" : "s"}`;
  const statusText = status === "accepted" ? "are going" : "changed to maybe";
  const dotColor = status === "accepted" ? "bg-green-500" : "bg-amber-500";

  return (
    <div className="flex items-center gap-2 px-2 py-1.5">
      <div className="flex -space-x-1.5">
        {items.slice(0, 3).map(i => (
          <Avatar key={i.id} name={i.user?.display_name} url={i.user?.avatar_url} size={20} className="border-2 border-card" />
        ))}
      </div>
      <p className="text-xs text-muted-foreground flex-1">
        <span className="font-medium text-foreground/80">{display}</span> {statusText}
      </p>
      <span className={`w-1.5 h-1.5 rounded-full ${dotColor}`} />
    </div>
  );
}

function SystemEventRow({ item }: { item: ActivityFeedItem }) {
  const isDate = item.type === "date_confirmed";
  const label = isDate
    ? `Date confirmed${item.content ? `: ${new Date(item.content).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" })}` : ""}`
    : `${item.content || "A game"} selected for the night`;

  return (
    <div className="flex items-center gap-2 px-2 py-2 bg-primary/5 rounded-lg my-0.5">
      {isDate ? <CalendarCheck className="w-3.5 h-3.5 text-primary" /> : <Gamepad2 className="w-3.5 h-3.5 text-primary" />}
      <span className="text-xs font-medium text-foreground/80 flex-1">{label}</span>
      <span className="text-[10px] text-muted-foreground/60">{relativeTime(item.created_at)}</span>
    </div>
  );
}

function CommentRow({ item, isHost, onReply, onTogglePin }: {
  item: ActivityFeedItem;
  isHost: boolean;
  onReply: () => void;
  onTogglePin: (id: string, pinned: boolean) => Promise<void>;
}) {
  const isAnnouncement = item.type === "announcement";

  const content = (
    <div className="flex items-start gap-2 px-2 py-2">
      <Avatar name={item.user?.display_name} url={item.user?.avatar_url} size={32} />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-sm font-semibold text-foreground">{item.user?.display_name || "Unknown"}</span>
          {isAnnouncement && <HostBadge />}
          <span className="text-[10px] text-muted-foreground">{relativeTime(item.created_at)}</span>
        </div>
        {item.content && <p className="text-sm text-muted-foreground leading-relaxed">{item.content}</p>}
        <div className="flex items-center gap-3 mt-1">
          <button onClick={onReply} className="text-[10px] text-muted-foreground hover:text-foreground">Reply</button>
          {item.replies && item.replies.length > 0 && (
            <span className="text-[10px] text-muted-foreground">{item.replies.length} {item.replies.length === 1 ? "reply" : "replies"}</span>
          )}
          {isHost && !item.is_pinned && (
            <button onClick={() => onTogglePin(item.id, true)} className="text-[10px] text-muted-foreground hover:text-foreground">Pin</button>
          )}
        </div>

        {/* Replies */}
        {item.replies && item.replies.length > 0 && (
          <div className="mt-2 ml-1 border-l-2 border-border pl-3 space-y-2">
            {item.replies.map(reply => (
              <div key={reply.id} className="flex items-start gap-1.5">
                <Avatar name={reply.user?.display_name} url={reply.user?.avatar_url} size={24} />
                <div>
                  <div className="flex items-center gap-1">
                    <span className="text-xs font-semibold text-foreground">{reply.user?.display_name || "Unknown"}</span>
                    <span className="text-[9px] text-muted-foreground">{relativeTime(reply.created_at)}</span>
                  </div>
                  {reply.content && <p className="text-xs text-muted-foreground">{reply.content}</p>}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );

  if (isAnnouncement) {
    return <div className="border-l-2 border-primary bg-primary/5 rounded-r-lg my-0.5">{content}</div>;
  }
  return content;
}

function HostBadge() {
  return (
    <span className="inline-flex items-center gap-0.5 text-[9px] font-bold text-primary bg-primary/10 px-1.5 py-0.5 rounded-full">
      <Megaphone className="w-2 h-2" /> HOST
    </span>
  );
}

function Avatar({ name, url, size, className = "" }: { name?: string | null; url?: string | null; size: number; className?: string }) {
  return (
    <div
      className={`rounded-full bg-muted flex items-center justify-center font-bold text-muted-foreground shrink-0 overflow-hidden ${className}`}
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      {url ? <img src={url} alt="" className="w-full h-full object-cover" /> : (name?.[0]?.toUpperCase() || "?")}
    </div>
  );
}

// ─── Grouping logic ───

interface GroupedFeedItem extends ActivityFeedItem {
  _grouped?: boolean;
  _groupedItems?: ActivityFeedItem[];
  _groupedStatus?: string;
}

function groupFeedItems(items: ActivityFeedItem[]): GroupedFeedItem[] {
  const pinned = items.filter(i => i.is_pinned);
  const unpinned = items.filter(i => !i.is_pinned);

  const result: GroupedFeedItem[] = [...pinned];
  let buffer: ActivityFeedItem[] = [];
  let currentStatus: string | null = null;

  const flush = () => {
    if (buffer.length >= 3) {
      result.push({
        ...buffer[0],
        _grouped: true,
        _groupedItems: buffer,
        _groupedStatus: currentStatus!,
      });
    } else {
      result.push(...buffer);
    }
    buffer = [];
    currentStatus = null;
  };

  for (const item of unpinned) {
    if (item.type === "rsvp_update") {
      if (currentStatus === item.content) {
        buffer.push(item);
      } else {
        flush();
        currentStatus = item.content || null;
        buffer.push(item);
      }
    } else {
      flush();
      result.push(item);
    }
  }
  flush();

  return result;
}
