import { useState } from "react";
import { Lock } from "lucide-react";
import type { InviteSummary, InviteUser } from "@/lib/types";

type VisibilityMode = "fullList" | "countsWithBlocker" | "countsOnly";

interface Props {
  summary: InviteSummary;
  visibilityMode: VisibilityMode;
  blockerMessage?: string;
  isHost: boolean;
  onViewAll?: () => void;
  onInvite?: () => void;
  canInvite?: boolean;
}

export function GuestListTabs({ summary, visibilityMode, blockerMessage, isHost, onViewAll, onInvite, canInvite }: Props) {
  const [selectedTab, setSelectedTab] = useState(0);

  const tabs = [
    { title: "Going", color: "bg-green-500", textColor: "text-green-500", users: summary.acceptedUsers },
    { title: "Maybe", color: "bg-amber-500", textColor: "text-amber-500", users: summary.maybeUsers },
    ...(isHost ? [
      { title: "Pending", color: "bg-muted-foreground", textColor: "text-muted-foreground", users: summary.pendingUsers },
      { title: "Can't Go", color: "bg-red-500", textColor: "text-red-500", users: summary.declinedUsers },
    ] : []),
  ].filter(t => t.users.length > 0);

  const maxVisible = 4;

  return (
    <div className="rounded-xl bg-card border border-border p-4 space-y-3">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h3 className="text-xs font-extrabold uppercase tracking-wider text-muted-foreground">Guest List</h3>
        <div className="flex items-center gap-3">
          {onViewAll && (
            <button onClick={onViewAll} className="text-xs font-semibold text-muted-foreground">See all</button>
          )}
          {canInvite && onInvite && (
            <button onClick={onInvite} className="text-xs font-semibold text-primary">Invite</button>
          )}
        </div>
      </div>

      {visibilityMode === "fullList" && tabs.length > 0 && (
        <>
          {/* Pill tabs */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {tabs.map((tab, i) => (
              <button
                key={tab.title}
                onClick={() => setSelectedTab(i)}
                className={`shrink-0 inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-semibold transition-colors ${
                  selectedTab === i
                    ? `${tab.color}/10 ${tab.textColor} bg-current/10`
                    : "bg-muted text-muted-foreground"
                }`}
                style={selectedTab === i ? { backgroundColor: `var(--tw-${tab.color})` } : undefined}
              >
                <span className={`w-1.5 h-1.5 rounded-full ${tab.color}`} />
                {tab.title} · {tab.users.length}
              </button>
            ))}
          </div>

          <div className="border-t border-border" />

          {/* Users list */}
          {tabs[selectedTab] && (
            <div className="space-y-0">
              {tabs[selectedTab].users.slice(0, maxVisible).map((user, i) => (
                <div key={user.id} className="flex items-center gap-2.5 py-1.5">
                  <span className={`w-1.5 h-1.5 rounded-full ${tabs[selectedTab].color}`} />
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
              ))}
              {tabs[selectedTab].users.length > maxVisible && onViewAll && (
                <button onClick={onViewAll} className="text-xs font-medium text-primary py-2">
                  See {tabs[selectedTab].users.length - maxVisible} more...
                </button>
              )}
            </div>
          )}
        </>
      )}

      {visibilityMode === "countsWithBlocker" && (
        <>
          {/* Count pills (non-interactive) */}
          <div className="flex gap-2 overflow-x-auto scrollbar-hide">
            {tabs.map(tab => (
              <span key={tab.title} className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-muted text-xs font-medium text-muted-foreground">
                <span className={`w-1.5 h-1.5 rounded-full ${tab.color}`} />
                {tab.title} · {tab.users.length}
              </span>
            ))}
          </div>
          <div className="border-t border-border" />
          <div className="flex flex-col items-center gap-2 py-6">
            <Lock className="w-5 h-5 text-muted-foreground" />
            <p className="text-sm text-muted-foreground text-center">{blockerMessage || "RSVP to see who's going."}</p>
          </div>
        </>
      )}

      {visibilityMode === "countsOnly" && (
        <div className="flex flex-col items-center gap-2 py-6">
          <Lock className="w-5 h-5 text-muted-foreground" />
          <p className="text-sm text-muted-foreground text-center">{blockerMessage || "Guest list not available."}</p>
        </div>
      )}
    </div>
  );
}
