import { supabase } from "@/lib/supabase";
import type { AppNotification } from "@/lib/types";

export async function fetchNotifications(): Promise<AppNotification[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return [];

  const { data, error } = await (supabase
    .from("notifications" as any)
    .select("*")
    .eq("user_id", user.id)
    .neq("type", "dm_received")
    .order("created_at", { ascending: false })
    .limit(50) as any);

  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

export async function fetchUnreadNotificationCount(): Promise<number> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return 0;

  const { count, error } = await (supabase
    .from("notifications" as any)
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .neq("type", "dm_received")
    .is("read_at", null) as any);

  if (error) return 0;
  return count ?? 0;
}

export async function markNotificationRead(id: string): Promise<void> {
  await (supabase
    .from("notifications" as any)
    .update({ read_at: new Date().toISOString() })
    .eq("id", id) as any);
}

export async function markAllNotificationsRead(): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  await (supabase
    .from("notifications" as any)
    .update({ read_at: new Date().toISOString() })
    .eq("user_id", user.id)
    .is("read_at", null) as any);
}

export function subscribeToNotifications(
  userId: string,
  callback: (notification: AppNotification) => void
) {
  const channel = supabase
    .channel("notifications-realtime")
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "notifications",
        filter: `user_id=eq.${userId}`,
      },
      (payload: any) => {
        callback(payload.new as AppNotification);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
