import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter, DialogClose,
} from "@/components/ui/dialog";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle, AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  ArrowLeft, User, LogOut, ChevronRight, Shield, Dice5, Bell, Palette,
  Trophy, CalendarDays, Lock, Trash2, Pencil, Crown, Star, Users, Package, Sparkles, Zap,
  BookUser, Phone, Search,
} from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import {
  fetchUserProfile, fetchProfileStats, fetchEventHistory,
  fetchBlockedUsers, unblockUser, updateUserProfile,
} from "@/lib/queries";
import { fetchAllContacts, type SavedContact } from "@/lib/contactQueries";
import { toast } from "@/hooks/use-toast";
import { GenerativeEventCover } from "@/components/GenerativeEventCover";
import { format } from "date-fns";

// ─── Badge Definitions ───
const BADGE_DEFS: { id: string; label: string; icon: React.ReactNode; check: (s: Stats) => boolean }[] = [
  { id: "first-night", label: "First Game Night", icon: <Dice5 className="w-3.5 h-3.5" />, check: (s) => s.attended >= 1 },
  { id: "host-hero", label: "Host Hero", icon: <Crown className="w-3.5 h-3.5" />, check: (s) => s.hosted >= 1 },
  { id: "regular", label: "Regular", icon: <CalendarDays className="w-3.5 h-3.5" />, check: (s) => s.attended >= 5 },
  { id: "collector", label: "Collector", icon: <Package className="w-3.5 h-3.5" />, check: (s) => s.gamesOwned >= 10 },
  { id: "social", label: "Social Butterfly", icon: <Sparkles className="w-3.5 h-3.5" />, check: () => false },
  { id: "champion", label: "Champion", icon: <Trophy className="w-3.5 h-3.5" />, check: () => false },
];

type Stats = { hosted: number; attended: number; gamesOwned: number; groups: number };

export default function Profile() {
  const { user, loading, signOut } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();

  // Dialogs
  const [editOpen, setEditOpen] = useState(false);
  const [privacyOpen, setPrivacyOpen] = useState(false);
  const [bggOpen, setBggOpen] = useState(false);
  const [blockedOpen, setBlockedOpen] = useState(false);
  const [contactsOpen, setContactsOpen] = useState(false);
  const [contactSearch, setContactSearch] = useState("");

  // Edit form
  const [editName, setEditName] = useState("");
  const [editBio, setEditBio] = useState("");

  // Privacy form
  const [phoneVisible, setPhoneVisible] = useState(false);
  const [discoverable, setDiscoverable] = useState(true);
  const [marketing, setMarketing] = useState(false);

  // BGG form
  const [bggUsername, setBggUsername] = useState("");

  // Theme
  const [theme, setTheme] = useState<"light" | "dark" | "system">(() => {
    return (localStorage.getItem("theme") as "light" | "dark" | "system") || "system";
  });

  const userId = user?.id;

  const { data: profile } = useQuery({
    queryKey: ["user-profile"],
    queryFn: fetchUserProfile,
    enabled: !!userId,
  });

  const { data: stats } = useQuery({
    queryKey: ["profile-stats", userId],
    queryFn: () => fetchProfileStats(userId!),
    enabled: !!userId,
  });

  const { data: eventHistory } = useQuery({
    queryKey: ["event-history", userId],
    queryFn: () => fetchEventHistory(userId!),
    enabled: !!userId,
  });

  const { data: blockedUsers, refetch: refetchBlocked } = useQuery({
    queryKey: ["blocked-users"],
    queryFn: fetchBlockedUsers,
    enabled: !!userId && blockedOpen,
  });

  const { data: savedContacts } = useQuery<SavedContact[]>({
    queryKey: ["all-contacts"],
    queryFn: fetchAllContacts,
    enabled: !!userId,
  });

  const updateMut = useMutation({
    mutationFn: (fields: Record<string, unknown>) => updateUserProfile(fields),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["user-profile"] });
      toast({ title: "Profile updated" });
    },
    onError: (e: Error) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const unblockMut = useMutation({
    mutationFn: unblockUser,
    onSuccess: () => {
      refetchBlocked();
      toast({ title: "User unblocked" });
    },
  });

  const handleSignOut = async () => {
    await signOut();
    navigate("/login");
  };

  const applyTheme = (t: "light" | "dark" | "system") => {
    setTheme(t);
    localStorage.setItem("theme", t);
    const root = document.documentElement;
    root.classList.remove("dark", "light");
    if (t === "dark") root.classList.add("dark");
    else if (t === "light") root.classList.remove("dark");
    else {
      if (window.matchMedia("(prefers-color-scheme: dark)").matches) root.classList.add("dark");
    }
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
          <Link to="/dashboard"><Button variant="ghost" size="icon" className="rounded-full"><ArrowLeft className="h-5 w-5" /></Button></Link>
          <h1 className="text-lg font-bold">Profile</h1>
        </header>
        <main className="px-6 pb-12 max-w-3xl mx-auto">
          <div className="rounded-xl bg-card p-8 flex flex-col items-center gap-4">
            <div className="h-20 w-20 rounded-full bg-muted flex items-center justify-center"><User className="h-8 w-8 text-muted-foreground" /></div>
            <div className="text-center space-y-1">
              <h2 className="text-lg font-bold">Not signed in</h2>
              <p className="text-sm text-muted-foreground">Sign in to manage your profile</p>
            </div>
            <Link to="/login"><Button>Sign In</Button></Link>
          </div>
        </main>
      </div>
    );
  }

  const displayName = profile?.display_name ?? user.user_metadata?.display_name ?? "Player";
  const phone = profile?.phone_number ?? user.phone ?? "";
  const maskedPhone = phone ? `***-***-${phone.slice(-4)}` : "";
  const joinedDate = profile?.created_at ? format(new Date(profile.created_at), "MMM yyyy") : "";
  const bio = profile?.bio ?? "";
  const s: Stats = stats ?? { hosted: 0, attended: 0, gamesOwned: 0, groups: 0 };

  return (
    <div className="min-h-screen bg-background pb-24 md:pb-0">
      <header className="px-6 py-4 max-w-3xl mx-auto flex items-center gap-3">
        <Link to="/dashboard">
          <Button variant="ghost" size="icon" className="rounded-full"><ArrowLeft className="h-5 w-5" /></Button>
        </Link>
        <h1 className="text-lg font-bold text-foreground">Profile</h1>
      </header>

      <main className="px-6 pb-12 max-w-3xl mx-auto space-y-5">
        {/* ─── Avatar + Info ─── */}
        <div className="rounded-xl bg-card p-6 flex flex-col items-center gap-3">
          <div className="h-20 w-20 rounded-full bg-primary/15 flex items-center justify-center">
            <span className="text-2xl font-bold text-primary">{displayName.charAt(0).toUpperCase()}</span>
          </div>
          <div className="text-center space-y-0.5">
            <h2 className="text-lg font-bold text-foreground">{displayName}</h2>
            <p className="text-sm text-muted-foreground">
              {maskedPhone}{maskedPhone && joinedDate ? " · " : ""}{joinedDate ? `Joined ${joinedDate}` : ""}
            </p>
            {bio && <p className="text-sm text-muted-foreground italic mt-1">"{bio}"</p>}
          </div>
          <Button
            variant="outline"
            size="sm"
            className="gap-1.5 mt-1"
            onClick={() => {
              setEditName(displayName);
              setEditBio(bio);
              setEditOpen(true);
            }}
          >
            <Pencil className="w-3.5 h-3.5" /> Edit Profile
          </Button>
        </div>

        {/* ─── Stats ─── */}
        <div className="grid grid-cols-4 gap-2.5">
          {([
            { label: "Hosted", value: s.hosted, icon: <Zap className="w-4 h-4 text-accent" />, color: "bg-accent/10" },
            { label: "Attended", value: s.attended, icon: <Dice5 className="w-4 h-4 text-primary" />, color: "bg-primary/10" },
            { label: "Games", value: s.gamesOwned, icon: <Package className="w-4 h-4 text-accent" />, color: "bg-accent/10" },
            { label: "Groups", value: s.groups, icon: <Users className="w-4 h-4 text-primary" />, color: "bg-primary/10" },
          ] as const).map((stat: any) => (
            <div key={stat.label} className="rounded-xl bg-card p-3 flex flex-col items-center gap-1.5 shadow-sm">
              <div className={`w-8 h-8 rounded-full ${stat.color} flex items-center justify-center`}>
                {stat.icon}
              </div>
              <span className="text-xl font-bold text-foreground tabular-nums">{stat.value}</span>
              <span className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">{stat.label}</span>
            </div>
          ))}
        </div>

        {/* ─── Badges ─── */}
        <div className="rounded-xl bg-card p-4 space-y-3">
          <div className="flex items-center gap-2">
            <Trophy className="w-4 h-4 text-accent" />
            <span className="font-semibold text-sm text-foreground">Badges</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {BADGE_DEFS.map((b) => {
              const unlocked = b.check(s);
              return (
                <Badge
                  key={b.id}
                  variant={unlocked ? "default" : "outline"}
                  className={`gap-1 text-xs py-1 px-2.5 ${
                    unlocked
                      ? "bg-primary/15 text-primary border-primary/30"
                      : "opacity-50 border-border text-muted-foreground"
                  }`}
                >
                  {unlocked ? b.icon : <Lock className="w-3 h-3" />} {b.label}
                </Badge>
              );
            })}
          </div>
          <p className="text-xs text-muted-foreground">More badges coming soon!</p>
        </div>

        {/* ─── Event History ─── */}
        <div className="rounded-xl bg-card p-4 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CalendarDays className="w-4 h-4 text-accent" />
              <span className="font-semibold text-sm text-foreground">Event History</span>
            </div>
            {eventHistory && eventHistory.length > 0 && (
              <button
                onClick={() => navigate("/calendar?view=list")}
                className="text-xs font-medium text-primary hover:text-primary/80 transition-colors active:scale-[0.97]"
              >
                View All
              </button>
            )}
          </div>
          {(!eventHistory || eventHistory.length === 0) ? (
            <div className="py-6 flex flex-col items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-muted/60 flex items-center justify-center">
                <CalendarDays className="w-5 h-5 text-muted-foreground" />
              </div>
              <p className="text-sm text-muted-foreground">No events attended yet</p>
            </div>
          ) : (
            <div className="space-y-2">
              {eventHistory.slice(0, 3).map((item: any) => {
                const ev = item.events;
                if (!ev) return null;
                return (
                  <Link
                    key={item.event_id}
                    to={`/events/${item.event_id}`}
                    className="group flex items-center gap-3 p-2.5 rounded-xl bg-muted/30 hover:bg-muted/60 transition-colors active:scale-[0.98]"
                  >
                    {ev.cover_image_url ? (
                      <img src={ev.cover_image_url} alt="" className="w-10 h-10 rounded-lg object-cover shrink-0" />
                    ) : (
                      <div className="w-10 h-10 rounded-lg overflow-hidden shrink-0">
                        <GenerativeEventCover title={ev.title} eventId={item.event_id} variant={ev.cover_variant ?? 0} className="w-full h-full" />
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-semibold text-foreground truncate">{ev.title}</p>
                      <p className="text-xs text-muted-foreground">
                        {ev.created_at ? format(new Date(ev.created_at), "MMM d, yyyy") : ""}
                        {ev.host?.display_name ? ` · Hosted by ${ev.host.display_name}` : ""}
                      </p>
                    </div>
                    <ChevronRight className="w-4 h-4 text-muted-foreground shrink-0 group-hover:translate-x-0.5 transition-transform" />
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* ─── My Contacts ─── */}
        <div className="rounded-xl bg-card overflow-hidden">
          <button
            onClick={() => { setContactSearch(""); setContactsOpen(true); }}
            className="w-full flex items-center justify-between px-4 py-3 hover:bg-muted/40 transition-colors active:scale-[0.98]"
          >
            <div className="flex items-center gap-3">
              <BookUser className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm font-medium text-foreground">My Contacts</span>
              {savedContacts && savedContacts.length > 0 && (
                <span className="text-xs text-muted-foreground">({savedContacts.length})</span>
              )}
            </div>
            <ChevronRight className="w-4 h-4 text-muted-foreground" />
          </button>
        </div>

        {/* ─── Settings ─── */}
        <div className="rounded-xl bg-card overflow-hidden">
          <SettingsRow icon={<Shield className="w-4 h-4" />} label="Privacy & Safety" onClick={() => {
            if (profile) {
              setPhoneVisible(profile.phone_visible ?? false);
              setDiscoverable(profile.discoverable_by_phone ?? true);
              setMarketing(profile.marketing_opt_in ?? false);
            }
            setPrivacyOpen(true);
          }} />
          <Separator />
          <SettingsRow icon={<Dice5 className="w-4 h-4" />} label="BoardGameGeek" onClick={() => {
            setBggUsername(profile?.bgg_username ?? "");
            setBggOpen(true);
          }} />
          <Separator />
          <SettingsRow icon={<Bell className="w-4 h-4" />} label="Notifications" onClick={() => toast({ title: "Coming soon" })} />
          <Separator />
          <div className="flex items-center justify-between px-4 py-3">
            <div className="flex items-center gap-3">
              <Palette className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm font-medium text-foreground">Appearance</span>
            </div>
            <div className="flex gap-1">
              {(["light", "dark", "system"] as const).map((t) => (
                <button
                  key={t}
                  onClick={() => applyTheme(t)}
                  className={`text-xs px-2.5 py-1 rounded-full capitalize transition-colors ${
                    theme === t
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted/60 text-muted-foreground hover:bg-muted"
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* ─── Sign Out ─── */}
        <Button variant="outline" className="w-full gap-2 text-destructive border-destructive/30 hover:bg-destructive/10" onClick={handleSignOut}>
          <LogOut className="w-4 h-4" /> Sign Out
        </Button>
      </main>

      {/* ─── Edit Profile Dialog ─── */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Edit Profile</DialogTitle>
            <DialogDescription>Update your display name and bio.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <label className="text-sm font-medium text-foreground">Display Name</label>
              <Input value={editName} onChange={(e) => setEditName(e.target.value)} placeholder="Your name" />
              <p className="text-xs text-muted-foreground">No real name required</p>
            </div>
            <div className="space-y-1.5">
              <label className="text-sm font-medium text-foreground">Bio</label>
              <Textarea value={editBio} onChange={(e) => setEditBio(e.target.value)} placeholder="Board game enthusiast..." rows={3} />
            </div>
          </div>
          <DialogFooter>
            <DialogClose asChild><Button variant="ghost">Cancel</Button></DialogClose>
            <Button
              disabled={!editName.trim() || updateMut.isPending}
              onClick={() => {
                updateMut.mutate({ display_name: editName.trim(), bio: editBio.trim() || null });
                setEditOpen(false);
              }}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Privacy Dialog ─── */}
      <Dialog open={privacyOpen} onOpenChange={setPrivacyOpen}>
        <DialogContent className="sm:max-w-md max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Privacy & Safety</DialogTitle>
            <DialogDescription>Manage your privacy settings.</DialogDescription>
          </DialogHeader>
          <div className="space-y-5 py-2">
            <PrivacyToggle
              label="Show phone to others"
              description="Other users can see your phone number"
              checked={phoneVisible}
              onChange={setPhoneVisible}
            />
            <PrivacyToggle
              label="Discoverable by phone"
              description="Others can find you by your phone number"
              checked={discoverable}
              onChange={setDiscoverable}
            />
            <PrivacyToggle
              label="Marketing emails"
              description="Receive updates and announcements"
              checked={marketing}
              onChange={setMarketing}
            />
            <Separator />
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-foreground">Blocked Users</span>
                <Button variant="ghost" size="sm" onClick={() => setBlockedOpen(true)}>
                  Manage
                </Button>
              </div>
            </div>
          </div>
          <DialogFooter>
            <DialogClose asChild><Button variant="ghost">Cancel</Button></DialogClose>
            <Button
              disabled={updateMut.isPending}
              onClick={() => {
                updateMut.mutate({
                  phone_visible: phoneVisible,
                  discoverable_by_phone: discoverable,
                  marketing_opt_in: marketing,
                });
                setPrivacyOpen(false);
              }}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Blocked Users Dialog ─── */}
      <Dialog open={blockedOpen} onOpenChange={setBlockedOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Blocked Users</DialogTitle>
            <DialogDescription>Users you've blocked can't invite you or see your profile.</DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-2">
            {(!blockedUsers || blockedUsers.length === 0) ? (
              <p className="text-sm text-muted-foreground py-4 text-center">No blocked users</p>
            ) : (
              blockedUsers.map((b: any) => (
                <div key={b.id} className="flex items-center justify-between py-2 px-1">
                  <span className="text-sm text-foreground">{b.blocked_phone ?? b.blocked_id?.slice(0, 8)}</span>
                  <Button
                    variant="outline"
                    size="sm"
                    className="text-xs"
                    disabled={unblockMut.isPending}
                    onClick={() => unblockMut.mutate(b.id)}
                  >
                    Unblock
                  </Button>
                </div>
              ))
            )}
          </div>
        </DialogContent>
      </Dialog>

      {/* ─── BGG Dialog ─── */}
      <Dialog open={bggOpen} onOpenChange={setBggOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>BoardGameGeek</DialogTitle>
            <DialogDescription>Link your BGG username to import your collection.</DialogDescription>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <Input
              value={bggUsername}
              onChange={(e) => setBggUsername(e.target.value)}
              placeholder="BGG username"
            />
          </div>
          <DialogFooter>
            <DialogClose asChild><Button variant="ghost">Cancel</Button></DialogClose>
            <Button
              disabled={updateMut.isPending}
              onClick={() => {
                updateMut.mutate({ bgg_username: bggUsername.trim() || null });
                setBggOpen(false);
              }}
            >
              {profile?.bgg_username ? "Update" : "Link"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Contacts Dialog ─── */}
      <Dialog open={contactsOpen} onOpenChange={setContactsOpen}>
        <DialogContent className="sm:max-w-md max-h-[85vh] overflow-hidden flex flex-col">
          <DialogHeader>
            <DialogTitle>My Contacts</DialogTitle>
            <DialogDescription>
              {savedContacts?.length ?? 0} saved {(savedContacts?.length ?? 0) === 1 ? "contact" : "contacts"}
            </DialogDescription>
          </DialogHeader>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
            <Input
              placeholder="Search contacts..."
              value={contactSearch}
              onChange={(e) => setContactSearch(e.target.value)}
              className="pl-9"
            />
          </div>
          <div className="flex-1 overflow-y-auto -mx-6 px-6 space-y-1 min-h-0">
            {(() => {
              const filtered = (savedContacts ?? []).filter(
                (c) =>
                  c.name.toLowerCase().includes(contactSearch.toLowerCase()) ||
                  c.phone_number.includes(contactSearch)
              );
              if (filtered.length === 0) {
                return (
                  <div className="py-10 flex flex-col items-center gap-2">
                    <BookUser className="w-8 h-8 text-muted-foreground/50" />
                    <p className="text-sm text-muted-foreground">
                      {contactSearch ? "No matching contacts" : "No contacts saved yet"}
                    </p>
                  </div>
                );
              }
              return filtered.map((c) => (
                <div key={c.id} className="flex items-center gap-3 py-2.5 px-1 rounded-lg">
                  <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                    <span className="text-sm font-semibold text-primary">
                      {c.name.charAt(0).toUpperCase()}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-1.5">
                      <p className="text-sm font-medium text-foreground truncate">{c.name}</p>
                      {c.is_app_user && (
                        <Badge variant="secondary" className="text-[10px] px-1.5 py-0 h-4 bg-primary/10 text-primary border-0">
                          GN
                        </Badge>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5">
                      <p className="text-xs text-muted-foreground">{c.phone_number}</p>
                      {c.source === "co-guest" && (
                        <span className="text-[10px] text-muted-foreground/70">· Co-guest</span>
                      )}
                      {c.source === "group" && (
                        <span className="text-[10px] text-muted-foreground/70">· Group</span>
                      )}
                    </div>
                  </div>
                </div>
              ));
            })()}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function SettingsRow({ icon, label, onClick }: { icon: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="w-full flex items-center justify-between px-4 py-3 hover:bg-muted/40 transition-colors active:scale-[0.99]">
      <div className="flex items-center gap-3">
        <span className="text-muted-foreground">{icon}</span>
        <span className="text-sm font-medium text-foreground">{label}</span>
      </div>
      <ChevronRight className="w-4 h-4 text-muted-foreground" />
    </button>
  );
}

function PrivacyToggle({ label, description, checked, onChange }: {
  label: string; description: string; checked: boolean; onChange: (v: boolean) => void;
}) {
  return (
    <div className="flex items-start justify-between gap-4">
      <div className="space-y-0.5">
        <p className="text-sm font-medium text-foreground">{label}</p>
        <p className="text-xs text-muted-foreground">{description}</p>
      </div>
      <Switch checked={checked} onCheckedChange={onChange} />
    </div>
  );
}
