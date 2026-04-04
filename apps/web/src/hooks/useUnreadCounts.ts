import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { fetchUnreadNotificationCount, subscribeToNotifications } from "@/lib/notificationQueries";
import { fetchConversations } from "@/lib/dmQueries";

export function useUnreadCounts() {
  const { user } = useAuth();
  const [notificationCount, setNotificationCount] = useState(0);
  const [messageCount, setMessageCount] = useState(0);

  const refresh = useCallback(async () => {
    if (!user) return;
    try {
      const [notifCount, convos] = await Promise.all([
        fetchUnreadNotificationCount(),
        fetchConversations().catch(() => []),
      ]);
      setNotificationCount(notifCount);
      setMessageCount(
        (convos ?? []).reduce((sum: number, c: any) => sum + (c.unread_count ?? 0), 0)
      );
    } catch {
      // silent
    }
  }, [user]);

  useEffect(() => {
    if (!user) return;
    refresh();

    const unsub = subscribeToNotifications(user.id, () => {
      refresh();
    });

    return unsub;
  }, [user, refresh]);

  return { notificationCount, messageCount, refresh };
}
