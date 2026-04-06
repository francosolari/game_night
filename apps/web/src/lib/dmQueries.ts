import { supabase } from "@/lib/supabase";
import type { ConversationSummary, DirectMessage } from "@/lib/types";

export async function fetchConversations(): Promise<ConversationSummary[]> {
  const { data, error } = await supabase.rpc("fetch_conversations_for_user" as any);
  if (error) throw error;
  return (data ?? []) as ConversationSummary[];
}

export async function fetchMessages(conversationId: string): Promise<DirectMessage[]> {
  const { data, error } = await (supabase
    .from("direct_messages" as any)
    .select("*, sender:sender_id(id, display_name, avatar_url)")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true })
    .limit(200) as any);

  if (error) throw error;
  return (data ?? []).map((m: any) => ({
    ...m,
    sender: m.sender ?? null,
  })) as DirectMessage[];
}

export async function sendDirectMessage(
  conversationId: string,
  content: string,
  messageType: string = "text",
  metadata?: any
): Promise<DirectMessage> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data, error } = await (supabase
    .from("direct_messages" as any)
    .insert({
      conversation_id: conversationId,
      sender_id: user.id,
      content,
      message_type: messageType,
      metadata: metadata ?? null,
    })
    .select("*")
    .single() as any);

  if (error) throw error;
  return data as DirectMessage;
}

export async function getOrCreateDM(otherUserId: string): Promise<string> {
  const { data, error } = await supabase.rpc("get_or_create_dm" as any, {
    p_other_user_id: otherUserId,
  });
  if (error) throw error;
  return data as string;
}

export async function markConversationRead(conversationId: string): Promise<void> {
  await supabase.rpc("mark_conversation_read" as any, {
    p_conversation_id: conversationId,
  });
}

export function subscribeToDirectMessages(
  conversationId: string,
  callback: (message: DirectMessage) => void
) {
  const channel = supabase
    .channel(`dm-${conversationId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "direct_messages",
        filter: `conversation_id=eq.${conversationId}`,
      },
      (payload: any) => {
        callback(payload.new as DirectMessage);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

export function subscribeToConversationUpdates(
  userId: string,
  callback: () => void
) {
  const channel = supabase
    .channel("inbox-updates")
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "direct_messages",
      },
      () => callback()
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
