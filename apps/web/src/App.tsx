import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, useLocation } from "react-router-dom";
import { Toaster as Sonner } from "@/components/ui/sonner.tsx";
import { Toaster } from "@/components/ui/toaster.tsx";
import { TooltipProvider } from "@/components/ui/tooltip.tsx";
import { AuthProvider } from "@/contexts/AuthContext.tsx";
import { MobileBottomNav } from "@/components/MobileBottomNav.tsx";
import { DesktopShell } from "@/components/DesktopShell.tsx";
import Index from "./pages/Index.tsx";
import InvitePreview from "./pages/InvitePreview.tsx";
import Login from "./pages/Login.tsx";
import Dashboard from "./pages/Dashboard.tsx";
import CreateEvent from "./pages/CreateEvent.tsx";
import EventDetail from "./pages/EventDetail.tsx";
import Profile from "./pages/Profile.tsx";
import GameLibrary from "./pages/GameLibrary.tsx";
import GameDetail from "./pages/GameDetail.tsx";
import CreatorDetail from "./pages/CreatorDetail.tsx";
import Calendar from "./pages/Calendar.tsx";
import Groups from "./pages/Groups.tsx";
import GroupDetail from "./pages/GroupDetail.tsx";
import NotFound from "./pages/NotFound.tsx";

const queryClient = new QueryClient();

/** Pages that should NOT get the desktop sidebar */
const NO_SHELL_ROUTES = ["/", "/login", "/invite"];

function AppRoutes() {
  const location = useLocation();
  const showShell = !NO_SHELL_ROUTES.some(r => location.pathname === r || location.pathname.startsWith(r + "/"))
    || location.pathname === "/dashboard";

  const routes = (
    <Routes>
      <Route path="/" element={<Index />} />
      <Route path="/login" element={<Login />} />
      <Route path="/invite/:token" element={<InvitePreview />} />
      <Route path="/dashboard" element={<Dashboard />} />
      <Route path="/events/new" element={<CreateEvent />} />
      <Route path="/events/:id" element={<EventDetail />} />
      <Route path="/profile" element={<Profile />} />
      <Route path="/games" element={<GameLibrary />} />
      <Route path="/games/:id" element={<GameDetail />} />
      <Route path="/games/:role/:name" element={<CreatorDetail />} />
      <Route path="/calendar" element={<Calendar />} />
      <Route path="/groups" element={<Groups />} />
      <Route path="/groups/:id" element={<GroupDetail />} />
      <Route path="*" element={<NotFound />} />
    </Routes>
  );

  if (showShell) {
    return (
      <>
        {/* Mobile: pages render their own mobile layout, shell is hidden */}
        <div className="md:hidden">{routes}</div>
        {/* Desktop: wrapped in sidebar shell */}
        <DesktopShell>{routes}</DesktopShell>
      </>
    );
  }

  return routes;
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <AuthProvider>
      <TooltipProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <AppRoutes />
          <MobileBottomNav />
        </BrowserRouter>
      </TooltipProvider>
    </AuthProvider>
  </QueryClientProvider>
);

export default App;
