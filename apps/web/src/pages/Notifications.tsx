import { useEffect, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, CheckCheck, ArrowLeft } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import { Skeleton } from "@/components/ui/skeleton";
import { NotificationRow } from "@/components/notifications/NotificationRow";
import {
  fetchNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  subscribeToNotifications,
} from "@/lib/notificationQueries";
import type { AppNotification } from "@/lib/types";

export default function Notifications() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const data = await fetchNotifications();
      setNotifications(data);
    } catch {
      // silent
    }
    setIsLoading(false);
  }, []);

  useEffect(() => {
    if (!user) { navigate("/login"); return; }
    load();

    const unsub = subscribeToNotifications(user.id, (n) => {
      if (n.type !== "dm_received") {
        setNotifications(prev => [n, ...prev]);
      }
    });

    return unsub;
  }, [user, navigate, load]);

  const handleTap = async (notification: AppNotification) => {
    if (!notification.read_at) {
      await markNotificationRead(notification.id);
      setNotifications(prev =>
        prev.map(n => n.id === notification.id ? { ...n, read_at: new Date().toISOString() } : n)
      );
    }
    if (notification.event_id) {
      navigate(`/events/${notification.event_id}`);
    } else if (notification.group_id) {
      navigate(`/groups/${notification.group_id}`);
    } else if (notification.conversation_id) {
      navigate(`/inbox/${notification.conversation_id}`);
    }
  };

  const handleMarkAllRead = async () => {
    await markAllNotificationsRead();
    setNotifications(prev =>
      prev.map(n => ({ ...n, read_at: n.read_at ?? new Date().toISOString() }))
    );
  };

  const allRead = notifications.every(n => n.read_at);

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <div className="sticky top-0 z-30 bg-background/95 backdrop-blur-sm border-b border-border/40">
        <div className="flex items-center justify-between px-4 py-3 max-w-2xl mx-auto">
          <button onClick={() => navigate(-1)} className="md:hidden w-9 h-9 flex items-center justify-center rounded-full hover:bg-muted/50">
            <ArrowLeft className="w-5 h-5 text-foreground" />
          </button>
          <h1 className="text-lg font-bold text-foreground">Notifications</h1>
          <button
            onClick={handleMarkAllRead}
            disabled={allRead || notifications.length === 0}
            className="text-xs font-semibold text-primary disabled:text-muted-foreground flex items-center gap-1"
          >
            <CheckCheck className="w-3.5 h-3.5" />
            Mark all read
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-2xl mx-auto">
        {isLoading ? (
          <div className="space-y-1">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="flex items-start gap-3 px-4 py-3.5">
                <Skeleton className="w-10 h-10 rounded-full" />
                <div className="flex-1 space-y-2">
                  <Skeleton className="h-4 w-3/4" />
                  <Skeleton className="h-3 w-1/2" />
                  <Skeleton className="h-2.5 w-16" />
                </div>
              </div>
            ))}
          </div>
        ) : notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-muted-foreground">
            <Bell className="w-14 h-14 mb-4 opacity-30" />
            <p className="text-base font-semibold">No Notifications</p>
            <p className="text-sm mt-1">You're all caught up!</p>
          </div>
        ) : (
          <div className="divide-y divide-border/30">
            {notifications.map(n => (
              <NotificationRow key={n.id} notification={n} onClick={() => handleTap(n)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
