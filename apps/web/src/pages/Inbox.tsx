import { useEffect, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { MessageCircle, PenSquare, ArrowLeft } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { Skeleton } from "@/components/ui/skeleton";
import { ConversationRow } from "@/components/inbox/ConversationRow";
import { NewMessageDialog } from "@/components/inbox/NewMessageDialog";
import { fetchConversations, subscribeToConversationUpdates } from "@/lib/dmQueries";
import type { ConversationSummary } from "@/lib/types";

export default function Inbox() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showNew, setShowNew] = useState(false);

  const load = useCallback(async () => {
    try {
      const data = await fetchConversations();
      setConversations(data);
    } catch {
      // silent
    }
    setIsLoading(false);
  }, []);

  useEffect(() => {
    if (!user) { navigate("/login"); return; }
    load();

    const unsub = subscribeToConversationUpdates(user.id, () => {
      load();
    });

    return unsub;
  }, [user, navigate, load]);

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <div className="sticky top-0 z-30 bg-background/95 backdrop-blur-sm border-b border-border/40">
        <div className="flex items-center justify-between px-4 py-3 max-w-2xl mx-auto">
          <button onClick={() => navigate(-1)} className="md:hidden w-9 h-9 flex items-center justify-center rounded-full hover:bg-muted/50">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </button>
          <h1 className="text-lg font-bold text-foreground">Messages</h1>
          <button
            onClick={() => setShowNew(true)}
            className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-muted/50"
          >
            <PenSquare className="w-5 h-5 text-primary" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-2xl mx-auto">
        {isLoading ? (
          <div className="space-y-1">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3.5">
                <Skeleton className="w-11 h-11 rounded-full" />
                <div className="flex-1 space-y-2">
                  <Skeleton className="h-4 w-1/3" />
                  <Skeleton className="h-3 w-2/3" />
                </div>
              </div>
            ))}
          </div>
        ) : conversations.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-muted-foreground">
            <MessageCircle className="w-14 h-14 mb-4 opacity-30" />
            <p className="text-base font-semibold">No Messages Yet</p>
            <p className="text-sm mt-1">Start a conversation with a friend</p>
            <button
              onClick={() => setShowNew(true)}
              className="mt-4 px-5 py-2 rounded-full bg-primary text-primary-foreground text-sm font-semibold"
            >
              New Message
            </button>
          </div>
        ) : (
          <div className="divide-y divide-border/30">
            {conversations.map(c => (
              <ConversationRow
                key={c.conversation_id}
                conversation={c}
                onClick={() => navigate(`/inbox/${c.conversation_id}`)}
              />
            ))}
          </div>
        )}
      </div>

      <NewMessageDialog
        open={showNew}
        onOpenChange={setShowNew}
        onConversationReady={(conversationId) => {
          navigate(`/inbox/${conversationId}`);
        }}
      />
    </div>
  );
}
