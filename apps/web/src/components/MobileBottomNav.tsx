import { Link, useLocation, useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";

export function MobileBottomNav() {
  const location = useLocation();
  const navigate = useNavigate();
  const path = location.pathname;

  // Don't show on login page
  if (path === "/login") return null;

  return (
    <nav
      className="md:hidden fixed bottom-0 inset-x-0 z-50 pb-[env(safe-area-inset-bottom)]"
      style={{ background: "hsl(var(--card))", boxShadow: "0 -5px 20px hsl(0 0% 0% / 0.08)" }}
    >
      <div className="flex items-center px-2 pt-2 pb-1">
        <TabBtn label="Home" href="/dashboard" active={path === "/dashboard" || path === "/"} icon={<IconHome />} />
        <TabBtn label="Games" href="/dashboard" active={false} icon={<IconDice />} />
        <div className="flex-1 flex justify-center">
          <button
            onClick={() => navigate("/events/new")}
            className="w-14 h-14 -mt-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center active:scale-95 transition-transform"
            style={{ boxShadow: "0 4px 12px hsl(94 19% 48% / 0.4)" }}
          >
            <Plus className="w-6 h-6" strokeWidth={2.5} />
          </button>
        </div>
        <TabBtn label="Groups" href="/dashboard" active={false} icon={<IconGroups />} />
        <TabBtn label="Profile" href="/profile" active={path === "/profile"} icon={<IconProfile />} />
      </div>
    </nav>
  );
}

function TabBtn({ icon, label, href, active }: { icon: React.ReactNode; label: string; href: string; active: boolean }) {
  return (
    <Link to={href} className={`flex-1 flex flex-col items-center gap-1 py-1 ${active ? "text-primary" : "text-muted-foreground"}`}>
      {icon}
      <span className="text-[10px] font-medium leading-none">{label}</span>
    </Link>
  );
}

function IconHome() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 3l9 8h-3v9h-5v-6h-2v6H6v-9H3l9-8z"/></svg>;
}
function IconDice() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M2 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2V4zm3 1a1 1 0 100 2 1 1 0 000-2zm3 3a1 1 0 100 2 1 1 0 000-2zM13 4a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2V4zm4.5.5a1 1 0 100 2 1 1 0 000-2zm-2 2a1 1 0 100 2 1 1 0 000-2zm2 2a1 1 0 100 2 1 1 0 000-2zM2 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2H4a2 2 0 01-2-2v-5zm3.5.5a1 1 0 100 2 1 1 0 000-2zm0 3a1 1 0 100 2 1 1 0 000-2zm-2-3a1 1 0 100 2 1 1 0 000-2zm4 3a1 1 0 100 2 1 1 0 000-2zM13 15a2 2 0 012-2h5a2 2 0 012 2v5a2 2 0 01-2 2h-5a2 2 0 01-2-2v-5zm2.5 2.5a2 2 0 104 0 2 2 0 00-4 0z"/></svg>;
}
function IconGroups() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 12.75c1.63 0 3.07.39 4.24.9 1.08.48 1.76 1.56 1.76 2.73V18H6v-1.61c0-1.18.68-2.26 1.76-2.73 1.17-.52 2.61-.91 4.24-.91zM4 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm1.13 1.1C4.76 14.04 4.39 14 4 14c-.99 0-1.93.21-2.78.58A2.01 2.01 0 000 16.43V18h4.5v-1.61c0-.83.23-1.61.63-2.29zM20 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm4 3.43c0-.81-.48-1.53-1.22-1.85A6.95 6.95 0 0020 14c-.39 0-.76.04-1.13.1.4.68.63 1.46.63 2.29V18H24v-1.57zM12 6c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z"/></svg>;
}
function IconProfile() {
  return <svg viewBox="0 0 24 24" fill="currentColor" className="w-[22px] h-[22px]"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2a7.2 7.2 0 01-6-3.22c.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08a7.2 7.2 0 01-6 3.22z"/></svg>;
}
