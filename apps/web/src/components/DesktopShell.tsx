import { Link, useLocation, useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import { useUnreadCounts } from "@/hooks/useUnreadCounts";
import meepleLogo from "@/assets/meeple_logo.png";

interface Props {
  children: React.ReactNode;
}

export function DesktopShell({ children }: Props) {
  const location = useLocation();
  const navigate = useNavigate();
  const path = location.pathname;
  const { notificationCount, messageCount } = useUnreadCounts();

  const isActive = (prefix: string) => {
    if (prefix === "/dashboard") return path === "/dashboard";
    return path.startsWith(prefix);
  };

  return (
    <div className="hidden md:flex min-h-screen bg-background">
      {/* Fixed left sidebar */}
      <aside
        className="w-[220px] lg:w-[240px] shrink-0 border-r border-border/60 flex flex-col sticky top-0 h-screen"
        style={{ background: "hsl(var(--card))" }}
      >
        <div className="px-5 pt-6 pb-4">
          <Link to="/dashboard" className="flex items-center gap-1.5">
            <h1 className="text-[15px] lg:text-base font-extrabold tracking-tight text-foreground leading-none whitespace-nowrap">
              CardboardWithMe
            </h1>
            <img src={meepleLogo} alt="" className="w-5 h-5 opacity-60" />
          </Link>
        </div>

        <nav className="flex-1 px-3 space-y-1">
          <SidebarLink label="Home" icon={<IconHome />} href="/dashboard" active={isActive("/dashboard")} />
          <SidebarLink label="Games" icon={<IconDice />} href="/games" active={isActive("/games")} />
          <SidebarLink label="Groups" icon={<IconGroups />} href="/groups" active={isActive("/groups")} />
          <SidebarLink label="Inbox" icon={<IconInbox />} href="/inbox" active={isActive("/inbox")} badge={messageCount} />
          <SidebarLink label="Notifications" icon={<IconBell />} href="/notifications" active={isActive("/notifications")} badge={notificationCount} />
          <SidebarLink label="Profile" icon={<IconProfile />} href="/profile" active={isActive("/profile")} />
        </nav>

        <div className="p-3">
          <button
            onClick={() => navigate("/events/new")}
            className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary text-primary-foreground font-semibold text-sm active:scale-[0.97] transition-transform"
            style={{ boxShadow: "0 2px 8px hsl(94 19% 48% / 0.3)" }}
          >
            <Plus className="w-4 h-4" strokeWidth={2.5} />
            New Event
          </button>
        </div>
      </aside>

      {/* Page content */}
      <main className="flex-1 min-w-0 overflow-y-auto">
        {children}
      </main>
    </div>
  );
}

function SidebarLink({ label, icon, href, active, badge }: { label: string; icon: React.ReactNode; href: string; active?: boolean; badge?: number }) {
  return (
    <Link
      to={href}
      className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors ${
        active
          ? "bg-primary/10 text-primary"
          : "text-muted-foreground hover:bg-muted/60 hover:text-foreground"
      }`}
    >
      <span className="w-5 h-5 flex items-center justify-center">{icon}</span>
      <span className="flex-1">{label}</span>
      {badge != null && badge > 0 && (
        <span className="min-w-[18px] h-[18px] rounded-full bg-primary text-primary-foreground text-[10px] font-bold flex items-center justify-center px-1">
          {badge > 99 ? "99+" : badge}
        </span>
      )}
    </Link>
  );
}

/* ─── SVG Icons (filled, matching iOS SF Symbols) ─── */
function IconHome() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 3l9 8h-3v9h-5v-6h-2v6H6v-9H3l9-8z"/></svg>;
}
function IconDice() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M2 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2V4zm3 1a1 1 0 100 2 1 1 0 000-2zm3 3a1 1 0 100 2 1 1 0 000-2zM13 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2V4zm4.5.5a1 1 0 100 2 1 1 0 000-2zm-2 2a1 1 0 100 2 1 1 0 000-2zm2 2a1 1 0 100 2 1 1 0 000-2zM2 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2v-5zm3.5.5a1 1 0 100 2 1 1 0 000-2zm0 3a1 1 0 100 2 1 1 0 000-2zm-2-3a1 1 0 100 2 1 1 0 000-2zm4 3a1 1 0 100 2 1 1 0 000-2zM13 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2v-5zm2.5 2.5a2 2 0 104 0 2 2 0 00-4 0z"/></svg>;
}
function IconGroups() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 12.75c1.63 0 3.07.39 4.24.9 1.08.48 1.76 1.56 1.76 2.73V18H6v-1.61c0-1.18.68-2.26 1.76-2.73 1.17-.52 2.61-.91 4.24-.91zM4 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm1.13 1.1C4.76 14.04 4.39 14 4 14c-.99 0-1.93.21-2.78.58A2.01 2.01 0 000 16.43V18h4.5v-1.61c0-.83.23-1.61.63-2.29zM20 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm4 3.43c0-.81-.48-1.53-1.22-1.85A6.95 6.95 0 0020 14c-.39 0-.76.04-1.13.1.4.68.63 1.46.63 2.29V18H24v-1.57zM12 6c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z"/></svg>;
}
function IconInbox() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>;
}
function IconBell() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z"/></svg>;
}
function IconProfile() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2a7.2 7.2 0 01-6-3.22c.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08a7.2 7.2 0 01-6 3.22z"/></svg>;
}
