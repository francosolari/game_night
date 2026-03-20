import { useState, useRef, useCallback } from "react";
import { X, Search, Lock } from "lucide-react";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import type { InviteSummary, InviteUser } from "@/lib/types";

type VisibilityMode = "fullList" | "countsWithBlocker" | "countsOnly";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  summary: InviteSummary;
  visibilityMode: VisibilityMode;
  blockerMessage?: string;
  isHost: boolean;
  canInvite?: boolean;
  onInvite?: () => void;
}

export function GuestListFullPage({ open, onOpenChange, summary, visibilityMode, blockerMessage, isHost, canInvite, onInvite }: Props) {
  const [selectedTab, setSelectedTab] = useState(0);
  const [searchText, setSearchText] = useState("");

  const tabs = [
    { title: "Going", dotColor: "bg-green-500", selectedBg: "bg-green-500/15", selectedText: "text-green-600 dark:text-green-400", users: summary.acceptedUsers },
    { title: "Maybe", dotColor: "bg-amber-500", selectedBg: "bg-amber-500/15", selectedText: "text-amber-600 dark:text-amber-400", users: summary.maybeUsers },
    ...(isHost ? [
      { title: "Pending", dotColor: "bg-muted-foreground", selectedBg: "bg-muted-foreground/15", selectedText: "text-foreground", users: summary.pendingUsers },
      { title: "Can't Go", dotColor: "bg-red-500", selectedBg: "bg-red-500/15", selectedText: "text-red-600 dark:text-red-400", users: summary.declinedUsers },
    ] : []),
  ].filter(t => t.users.length > 0);

  const totalGuests = tabs.reduce((sum, t) => sum + t.users.length, 0);

  const filterUsers = (users: InviteUser[]) => {
    if (!searchText.trim()) return users;
    const q = searchText.toLowerCase();
    return users.filter(u => u.name.toLowerCase().includes(q));
  };

  const currentTab = tabs[selectedTab];
  const filteredUsers = currentTab ? filterUsers(currentTab.users) : [];

  // Swipe support
  const touchStart = useRef<number | null>(null);
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    touchStart.current = e.touches[0].clientX;
  }, []);
  const handleTouchEnd = useCallback((e: React.TouchEvent) => {
    if (touchStart.current === null) return;
    const diff = touchStart.current - e.changedTouches[0].clientX;
    if (Math.abs(diff) > 50) {
      setSelectedTab(prev => {
        if (diff > 0) return Math.min(prev + 1, tabs.length - 1);
        return Math.max(prev - 1, 0);
      });
    }
    touchStart.current = null;
  }, [tabs.length]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg w-full p-0 gap-0 max-h-[85vh] flex flex-col [&>button]:hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-border shrink-0">
          <button
            onClick={() => onOpenChange(false)}
            className="text-sm font-semibold text-primary"
          >
            Done
          </button>
          <h2 className="text-sm font-bold text-foreground">Guest List</h2>
          {canInvite && onInvite ? (
            <button
              onClick={() => { onInvite(); onOpenChange(false); }}
              className="text-sm font-semibold text-primary"
            >
              Invite
            </button>
          ) : (
            <span className="w-12" />
          )}
        </div>

        {/* Search (show when 10+ guests) */}
        {totalGuests > 10 && visibilityMode === "fullList" && (
          <div className="px-4 pt-3 shrink-0">
            <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-muted">
              <Search className="w-4 h-4 text-muted-foreground shrink-0" />
              <input
                type="text"
                placeholder="Search guests..."
                value={searchText}
                onChange={e => setSearchText(e.target.value)}
                className="flex-1 bg-transparent text-sm text-foreground placeholder:text-muted-foreground outline-none"
              />
            </div>
          </div>
        )}

        {visibilityMode === "fullList" && tabs.length > 0 && (
          <>
            {/* Pill tabs */}
            <div className="flex gap-2 px-4 pt-3 pb-2 overflow-x-auto scrollbar-hide shrink-0">
              {tabs.map((tab, i) => {
                const filtered = filterUsers(tab.users);
                const isSelected = selectedTab === i;
                return (
                  <button
                    key={tab.title}
                    onClick={() => setSelectedTab(i)}
                    className={`shrink-0 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold transition-colors ${
                      isSelected
                        ? `${tab.selectedBg} ${tab.selectedText}`
                        : "bg-muted text-muted-foreground"
                    }`}
                  >
                    <span className={`w-1.5 h-1.5 rounded-full ${tab.dotColor}`} />
                    {tab.title} · {filtered.length}
                  </button>
                );
              })}
            </div>

            {/* Guest list — scrollable */}
            <div className="flex-1 overflow-y-auto px-4 pb-4" onTouchStart={handleTouchStart} onTouchEnd={handleTouchEnd}>
              {filteredUsers.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-8">No guests found</p>
              ) : (
                <div className="space-y-0">
                  {filteredUsers.map((user, i) => (
                    <div key={user.id}>
                      <div className="flex items-center gap-2.5 py-2">
                        <span className={`w-1.5 h-1.5 rounded-full ${currentTab?.dotColor}`} />
                        <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground shrink-0 overflow-hidden">
                          {user.avatarUrl ? (
                            <img src={user.avatarUrl} alt="" className="w-full h-full object-cover" />
                          ) : (
                            user.name[0]?.toUpperCase() || "?"
                          )}
                        </div>
                        <span className="text-sm font-medium text-foreground flex-1 truncate">{user.name}</span>
                        {user.tier > 1 && <span className="text-xs text-muted-foreground">Tier {user.tier}</span>}
                      </div>
                      {i < filteredUsers.length - 1 && (
                        <div className="border-t border-border ml-[46px]" />
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}

        {visibilityMode === "countsWithBlocker" && (
          <div className="flex-1 flex flex-col items-center justify-center gap-3 py-12 px-4">
            <div className="flex gap-2 flex-wrap justify-center mb-4">
              {tabs.map(tab => (
                <span key={tab.title} className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-muted text-xs font-medium text-muted-foreground">
                  <span className={`w-1.5 h-1.5 rounded-full ${tab.dotColor}`} />
                  {tab.title} · {tab.users.length}
                </span>
              ))}
            </div>
            <Lock className="w-5 h-5 text-muted-foreground" />
            <p className="text-sm text-muted-foreground text-center">{blockerMessage || "RSVP to see who's going."}</p>
          </div>
        )}

        {visibilityMode === "countsOnly" && (
          <div className="flex-1 flex flex-col items-center justify-center gap-3 py-12 px-4">
            <Lock className="w-5 h-5 text-muted-foreground" />
            <p className="text-sm text-muted-foreground text-center">{blockerMessage || "Guest list not available."}</p>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
