import { useState, useEffect, useRef } from "react";
import { Send, Reply, User } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { fetchGroupMessages, postGroupMessage, subscribeToGroupMessages } from "@/lib/groupQueries";
import { buildMessageTree } from "@/lib/groupTypes";
import type { GroupMessage } from "@/lib/groupTypes";
import { Skeleton } from "@/components/ui/skeleton";

interface ChatTabProps {
  groupId: string;
}

export function ChatTab({ groupId }: ChatTabProps) {
  const [messages, setMessages] = useState<GroupMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [text, setText] = useState("");
  const [replyTo, setReplyTo] = useState<GroupMessage | null>(null);
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  const load = async () => {
    try {
      const raw = await fetchGroupMessages(groupId);
      setMessages(buildMessageTree(raw));
    } catch {
      // table may not exist
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    const channel = subscribeToGroupMessages(groupId, () => { load(); });
    return () => { channel.unsubscribe(); };
  }, [groupId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = async () => {
    if (!text.trim()) return;
    setSending(true);
    try {
      await postGroupMessage(groupId, text.trim(), replyTo?.id);
      setText("");
      setReplyTo(null);
      await load();
    } catch {
      toast.error("Failed to send message");
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="flex gap-2">
            <Skeleton className="w-8 h-8 rounded-full shrink-0" />
            <div className="flex-1 space-y-1">
              <Skeleton className="h-3 w-20" />
              <Skeleton className="h-4 w-3/4" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="flex flex-col h-[400px]">
      {/* Messages */}
      <div className="flex-1 overflow-y-auto space-y-3 pb-3">
        {messages.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-8">No messages yet. Start the conversation!</p>
        ) : (
          messages.map(msg => (
            <MessageBubble key={msg.id} message={msg} onReply={setReplyTo} />
          ))
        )}
        <div ref={bottomRef} />
      </div>

      {/* Reply chip */}
      {replyTo && (
        <div className="flex items-center gap-2 px-3 py-1.5 bg-muted/60 rounded-t-lg">
          <Reply className="w-3 h-3 text-muted-foreground" />
          <span className="text-[11px] text-muted-foreground truncate flex-1">
            Replying to {replyTo.user?.display_name ?? "Unknown"}
          </span>
          <button onClick={() => setReplyTo(null)} className="text-xs text-muted-foreground hover:text-foreground">✕</button>
        </div>
      )}

      {/* Input */}
      <div className="flex gap-2 pt-2 border-t border-border/40">
        <Input
          value={text}
          onChange={e => setText(e.target.value)}
          placeholder="Message…"
          className="flex-1"
          onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(); } }}
        />
        <button
          onClick={handleSend}
          disabled={!text.trim() || sending}
          className="w-9 h-9 rounded-full bg-primary text-primary-foreground flex items-center justify-center disabled:opacity-50 active:scale-95 transition-transform"
        >
          <Send className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}

function MessageBubble({ message, onReply, depth = 0 }: { message: GroupMessage; onReply: (msg: GroupMessage) => void; depth?: number }) {
  return (
    <div className={depth > 0 ? "ml-6 pl-3 border-l-2 border-border/40" : ""}>
      <div className="flex gap-2 group">
        <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center shrink-0 mt-0.5">
          {message.user?.avatar_url ? (
            <img src={message.user.avatar_url} alt="" className="w-full h-full rounded-full object-cover" />
          ) : (
            <User className="w-3.5 h-3.5 text-muted-foreground" />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-[12px] font-semibold text-foreground">{message.user?.display_name ?? "Unknown"}</span>
            <span className="text-[10px] text-muted-foreground">
              {formatDistanceToNow(new Date(message.created_at), { addSuffix: true })}
            </span>
          </div>
          <p className="text-[13px] text-foreground/90 mt-0.5">{message.content}</p>
          <button
            onClick={() => onReply(message)}
            className="text-[10px] text-muted-foreground hover:text-primary mt-1 opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-0.5"
          >
            <Reply className="w-3 h-3" />
            Reply
          </button>
        </div>
      </div>
      {message.replies?.map(reply => (
        <MessageBubble key={reply.id} message={reply} onReply={onReply} depth={depth + 1} />
      ))}
    </div>
  );
}
