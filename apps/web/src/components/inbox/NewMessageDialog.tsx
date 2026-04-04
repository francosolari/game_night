import { useState, useEffect } from "react";
import { Search, MessageCircle } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { fetchAllContacts, type SavedContact } from "@/lib/contactQueries";
import { getOrCreateDM } from "@/lib/dmQueries";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConversationReady: (conversationId: string, otherUser: { id: string; name: string; avatarUrl: string | null }) => void;
}

export function NewMessageDialog({ open, onOpenChange, onConversationReady }: Props) {
  const [contacts, setContacts] = useState<SavedContact[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [startingDM, setStartingDM] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setIsLoading(true);
    fetchAllContacts()
      .then(setContacts)
      .catch(() => {})
      .finally(() => setIsLoading(false));
  }, [open]);

  const filtered = contacts.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.phone_number.includes(search)
  );

  const appUsers = filtered.filter(c => c.is_app_user);
  const otherUsers = filtered.filter(c => !c.is_app_user);

  const handleSelect = async (contact: SavedContact) => {
    if (!contact.is_app_user) return;
    // We need the user_id — look it up or use the id if it's a UUID
    // For co-guests/group members, the id might be prefixed. We need user_id from the contact.
    // The contact system doesn't store user_id directly, so we need a lookup
    setStartingDM(contact.phone_number);
    try {
      // Look up user by phone
      const { data: userData } = await (await import("@/lib/supabase")).supabase
        .from("users")
        .select("id")
        .eq("phone_number", contact.phone_number)
        .single();

      if (!userData) throw new Error("User not found");

      const conversationId = await getOrCreateDM(userData.id);
      onConversationReady(conversationId, {
        id: userData.id,
        name: contact.name,
        avatarUrl: contact.avatar_url ?? null,
      });
      onOpenChange(false);
    } catch {
      // silent
    } finally {
      setStartingDM(null);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md max-h-[80vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>New Message</DialogTitle>
        </DialogHeader>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search contacts..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
          />
        </div>

        {/* Contact list */}
        <div className="flex-1 overflow-y-auto -mx-6 min-h-0">
          {isLoading ? (
            <div className="px-6 space-y-3 py-2">
              {[1, 2, 3, 4].map(i => (
                <div key={i} className="flex items-center gap-3">
                  <Skeleton className="w-10 h-10 rounded-full" />
                  <div className="space-y-1.5 flex-1">
                    <Skeleton className="h-3.5 w-24" />
                    <Skeleton className="h-3 w-16" />
                  </div>
                </div>
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <MessageCircle className="w-10 h-10 mb-3 opacity-40" />
              <p className="text-sm font-medium">No contacts found</p>
            </div>
          ) : (
            <>
              {appUsers.length > 0 && (
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground px-6 py-2">
                    On CardboardWithMe
                  </p>
                  {appUsers.map(c => (
                    <ContactRow
                      key={c.phone_number}
                      contact={c}
                      isStarting={startingDM === c.phone_number}
                      onSelect={() => handleSelect(c)}
                    />
                  ))}
                </div>
              )}
              {otherUsers.length > 0 && (
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground px-6 py-2 mt-2">
                    Not on the App
                  </p>
                  {otherUsers.map(c => (
                    <ContactRow
                      key={c.phone_number}
                      contact={c}
                      disabled
                      onSelect={() => {}}
                    />
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}

function ContactRow({
  contact,
  disabled,
  isStarting,
  onSelect,
}: {
  contact: SavedContact;
  disabled?: boolean;
  isStarting?: boolean;
  onSelect: () => void;
}) {
  const initials = contact.name
    .split(" ")
    .map(w => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <button
      onClick={onSelect}
      disabled={disabled || isStarting}
      className="w-full flex items-center gap-3 px-6 py-2.5 text-left hover:bg-muted/40 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
    >
      <Avatar className="w-10 h-10">
        <AvatarImage src={contact.avatar_url ?? undefined} />
        <AvatarFallback className="bg-muted text-muted-foreground text-xs font-bold">
          {initials}
        </AvatarFallback>
      </Avatar>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground truncate">{contact.name}</p>
        <p className="text-[12px] text-muted-foreground">{contact.phone_number}</p>
      </div>
      {disabled && (
        <span className="text-[10px] font-semibold text-muted-foreground bg-muted px-2 py-0.5 rounded-full">
          Not on app
        </span>
      )}
      {isStarting && (
        <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      )}
    </button>
  );
}
