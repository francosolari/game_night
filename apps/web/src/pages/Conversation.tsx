import { useEffect, useState, useCallback, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { ArrowLeft, Send } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { Skeleton } from "@/components/ui/skeleton";
import { MessageBubble } from "@/components/inbox/MessageBubble";
import {
  fetchMessages,
  sendDirectMessage,
  markConversationRead,
  subscribeToDirectMessages,
} from "@/lib/dmQueries";
import type { DirectMessage } from "@/lib/types";

export default function Conversation() {
  const { conversationId } = useParams<{ conversationId: string }>();
  const { user } = useAuth();
  const navigate = useNavigate();

  const [messages, setMessages] = useState<DirectMessage[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [newMessage, setNewMessage] = useState("");
  const [isSending, setIsSending] = useState(false);
  const [otherName, setOtherName] = useState("Conversation");

  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const scrollToBottom = useCallback((smooth = true) => {
    bottomRef.current?.scrollIntoView({ behavior: smooth ? "smooth" : "instant" });
  }, []);

  const load = useCallback(async () => {
    if (!conversationId) return;
    try {
      const msgs = await fetchMessages(conversationId);
      setMessages(msgs);

      // Derive other user name from messages
      if (msgs.length > 0 && user) {
        const other = msgs.find(m => m.sender_id !== user.id);
        if (other?.sender?.display_name) setOtherName(other.sender.display_name);
      }

      await markConversationRead(conversationId);
    } catch {
      // silent
    }
    setIsLoading(false);
  }, [conversationId, user]);

  useEffect(() => {
    if (!user) { navigate("/login"); return; }
    load();
  }, [user, navigate, load]);

  // Scroll to bottom on load and new messages
  useEffect(() => {
    if (!isLoading && messages.length > 0) {
      scrollToBottom(false);
    }
  }, [isLoading, messages.length, scrollToBottom]);

  // Realtime subscription
  useEffect(() => {
    if (!conversationId || !user) return;

    const unsub = subscribeToDirectMessages(conversationId, (msg) => {
      setMessages(prev => {
        if (prev.some(m => m.id === msg.id)) return prev;
        return [...prev, msg];
      });
      scrollToBottom();
      // Mark as read if from other
      if (msg.sender_id !== user.id) {
        markConversationRead(conversationId);
      }
    });

    return unsub;
  }, [conversationId, user, scrollToBottom]);

  const handleSend = async () => {
    if (!newMessage.trim() || !conversationId || isSending) return;
    const text = newMessage.trim();
    setNewMessage("");
    setIsSending(true);

    try {
      const msg = await sendDirectMessage(conversationId, text);
      setMessages(prev => {
        if (prev.some(m => m.id === msg.id)) return prev;
        return [...prev, { ...msg, sender: { id: user!.id, display_name: user!.user_metadata?.display_name ?? "You", avatar_url: null } }];
      });
      scrollToBottom();
    } catch {
      // Restore message on error
      setNewMessage(text);
    }
    setIsSending(false);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="sticky top-0 z-30 bg-background/95 backdrop-blur-sm border-b border-border/40">
        <div className="flex items-center gap-3 px-4 py-3 max-w-2xl mx-auto">
          <button onClick={() => navigate("/inbox")} className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-muted/50">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </button>
          <h1 className="text-base font-bold text-foreground truncate">{otherName}</h1>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto max-w-2xl mx-auto w-full">
        <div className="px-4 py-4">
          {isLoading ? (
            <div className="space-y-4">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className={`flex ${i % 2 ? "justify-end" : "justify-start"}`}>
                  <Skeleton className={`h-10 rounded-2xl ${i % 2 ? "w-1/3" : "w-2/5"}`} />
                </div>
              ))}
            </div>
          ) : messages.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 text-muted-foreground">
              <p className="text-2xl mb-2">👋</p>
              <p className="text-sm font-medium">Say hello!</p>
            </div>
          ) : (
            messages.map(msg => (
              <MessageBubble
                key={msg.id}
                message={msg}
                isMine={msg.sender_id === user?.id}
                onInviteTap={(eventId) => navigate(`/events/${eventId}`)}
              />
            ))
          )}
          <div ref={bottomRef} />
        </div>
      </div>

      {/* Input bar */}
      <div className="sticky bottom-0 bg-background/95 backdrop-blur-sm border-t border-border/40">
        <div className="flex items-center gap-2 px-4 py-3 max-w-2xl mx-auto">
          <input
            ref={inputRef}
            type="text"
            value={newMessage}
            onChange={e => setNewMessage(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Message..."
            className="flex-1 px-4 py-2.5 rounded-full bg-muted/50 border border-border/60 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
          />
          <button
            onClick={handleSend}
            disabled={!newMessage.trim() || isSending}
            className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center disabled:opacity-40 active:scale-95 transition-transform"
          >
            {isSending ? (
              <div className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
            ) : (
              <Send className="w-4 h-4" />
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
