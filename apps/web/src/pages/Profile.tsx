import { Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { ArrowLeft, User, LogOut } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";

export default function Profile() {
  const { user, loading, signOut } = useAuth();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
    navigate("/login");
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="min-h-screen bg-background">
        <header className="px-6 py-4 max-w-3xl mx-auto flex items-center gap-3">
          <Link to="/dashboard">
            <Button variant="ghost" size="icon" className="rounded-full">
              <ArrowLeft className="h-5 w-5" />
            </Button>
          </Link>
          <h1 className="text-lg font-bold">Profile</h1>
        </header>
        <main className="px-6 pb-12 max-w-3xl mx-auto">
          <div className="rounded-xl bg-card p-8 flex flex-col items-center gap-4">
            <div className="h-20 w-20 rounded-full bg-muted flex items-center justify-center">
              <User className="h-8 w-8 text-muted-foreground" />
            </div>
            <div className="text-center space-y-1">
              <h2 className="text-lg font-bold">Not signed in</h2>
              <p className="text-sm text-muted-foreground">Sign in to manage your profile</p>
            </div>
            <Link to="/login">
              <Button>Sign In</Button>
            </Link>
          </div>
        </main>
      </div>
    );
  }

  const phone = user.phone ?? "";
  const displayName = user.user_metadata?.display_name ?? phone;

  return (
    <div className="min-h-screen bg-background pb-24 md:pb-0">
      <header className="px-6 py-4 max-w-3xl mx-auto flex items-center gap-3">
        <Link to="/dashboard">
          <Button variant="ghost" size="icon" className="rounded-full">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <h1 className="text-lg font-bold">Profile</h1>
      </header>

      <main className="px-6 pb-12 max-w-3xl mx-auto space-y-4">
        <div className="rounded-xl bg-card p-6 flex flex-col items-center gap-4">
          <div className="h-20 w-20 rounded-full bg-primary/15 flex items-center justify-center">
            <span className="text-2xl font-bold text-primary">
              {displayName.charAt(0).toUpperCase()}
            </span>
          </div>
          <div className="text-center space-y-1">
            <h2 className="text-lg font-bold text-foreground">{displayName}</h2>
            {phone && <p className="text-sm text-muted-foreground">{phone}</p>}
          </div>
        </div>

        <Button variant="outline" className="w-full gap-2" onClick={handleSignOut}>
          <LogOut className="w-4 h-4" />
          Sign Out
        </Button>
      </main>
    </div>
  );
}
