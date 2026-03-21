import { useState, useEffect, useMemo } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search, UserPlus, Check, Smartphone } from "lucide-react";
import { fetchAllContacts, type SavedContact } from "@/lib/contactQueries";
import { Skeleton } from "@/components/ui/skeleton";

interface ContactListSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  excludedPhones?: Set<string>;
  onSelect: (contacts: { name: string; phone_number: string }[]) => void;
}

export function ContactListSheet({ open, onOpenChange, excludedPhones = new Set(), onSelect }: ContactListSheetProps) {
  const [allFetchedContacts, setAllFetchedContacts] = useState<SavedContact[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  // Manual add fields
  const [showManual, setShowManual] = useState(false);
  const [manualName, setManualName] = useState("");
  const [manualPhone, setManualPhone] = useState("");
  const [manualAdded, setManualAdded] = useState<{ name: string; phone_number: string }[]>([]);

  useEffect(() => {
    if (!open) return;
    setSelected(new Set());
    setSearch("");
    setShowManual(false);
    setManualAdded([]);
    loadContacts();
  }, [open]);

  const loadContacts = async () => {
    setLoading(true);
    try {
      const contacts = await fetchAllContacts();
      setAllFetchedContacts(contacts);
    } catch {
      // Graceful fallback
    } finally {
      setLoading(false);
    }
  };

  const allContacts = useMemo(() => {
    return allFetchedContacts.filter(c => !excludedPhones.has(c.phone_number));
  }, [allFetchedContacts, excludedPhones]);

  const filtered = useMemo(() => {
    if (!search.trim()) return allContacts;
    const q = search.toLowerCase();
    return allContacts.filter(c =>
      c.name.toLowerCase().includes(q) || c.phone_number.includes(q)
    );
  }, [allContacts, search]);

  const appUsers = filtered.filter(c => c.is_app_user);
  const others = filtered.filter(c => !c.is_app_user);

  const toggleSelect = (phone: string) => {
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(phone)) next.delete(phone);
      else next.add(phone);
      return next;
    });
  };

  const handleAddManual = () => {
    if (!manualName.trim() || !manualPhone.trim()) return;
    setManualAdded(prev => [...prev, { name: manualName.trim(), phone_number: manualPhone.trim() }]);
    setManualName("");
    setManualPhone("");
  };

  const handleDone = () => {
    const fromContacts = allContacts
      .filter(c => selected.has(c.phone_number))
      .map(c => ({ name: c.name, phone_number: c.phone_number }));
    onSelect([...fromContacts, ...manualAdded]);
    onOpenChange(false);
  };

  const totalCount = selected.size + manualAdded.length;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[80vh] flex flex-col">
        <DialogHeader>
          <DialogTitle className="text-base font-bold">Add People</DialogTitle>
        </DialogHeader>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search contacts…"
            className="pl-9"
          />
        </div>

        {/* Contact list */}
        <div className="flex-1 overflow-y-auto min-h-0 space-y-1 -mx-1 px-1" style={{ maxHeight: "40vh" }}>
          {loading ? (
            <div className="space-y-2 py-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex items-center gap-3 px-2">
                  <Skeleton className="w-8 h-8 rounded-full shrink-0" />
                  <div className="flex-1 space-y-1">
                    <Skeleton className="h-3 w-24" />
                    <Skeleton className="h-2.5 w-32" />
                  </div>
                </div>
              ))}
            </div>
          ) : allContacts.length === 0 && manualAdded.length === 0 ? (
            <div className="text-center py-8 space-y-2">
              <p className="text-sm text-muted-foreground">No saved contacts yet</p>
              <p className="text-xs text-muted-foreground">Add people manually below</p>
            </div>
          ) : (
            <>
              {/* App users section */}
              {appUsers.length > 0 && (
                <>
                  <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider px-2 pt-2">
                    On Game Night
                  </p>
                  {appUsers.map(c => (
                    <ContactRow
                      key={c.phone_number}
                      contact={c}
                      isSelected={selected.has(c.phone_number)}
                      onToggle={() => toggleSelect(c.phone_number)}
                    />
                  ))}
                </>
              )}

              {/* Other contacts */}
              {others.length > 0 && (
                <>
                  <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider px-2 pt-3">
                    {appUsers.length > 0 ? "Other Contacts" : "Contacts"}
                  </p>
                  {others.map(c => (
                    <ContactRow
                      key={c.phone_number}
                      contact={c}
                      isSelected={selected.has(c.phone_number)}
                      onToggle={() => toggleSelect(c.phone_number)}
                    />
                  ))}
                </>
              )}

              {/* Manually added contacts preview */}
              {manualAdded.length > 0 && (
                <>
                  <p className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider px-2 pt-3">
                    Added Manually
                  </p>
                  {manualAdded.map((c, i) => (
                    <div key={i} className="flex items-center gap-3 px-2 py-2 rounded-lg bg-primary/5">
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-xs font-bold text-primary shrink-0">
                        {c.name.charAt(0).toUpperCase()}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-foreground truncate">{c.name}</p>
                        <p className="text-xs text-muted-foreground">{c.phone_number}</p>
                      </div>
                      <Check className="w-4 h-4 text-primary" />
                    </div>
                  ))}
                </>
              )}
            </>
          )}
        </div>

        {/* Manual add toggle */}
        {showManual ? (
          <div className="space-y-2 pt-2 border-t border-border/50">
            <p className="text-xs font-medium text-muted-foreground">Add by name & phone</p>
            <div className="flex gap-2">
              <Input
                value={manualName}
                onChange={e => setManualName(e.target.value)}
                placeholder="Name"
                className="flex-1"
              />
              <Input
                value={manualPhone}
                onChange={e => setManualPhone(e.target.value)}
                placeholder="Phone"
                className="flex-1"
              />
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={handleAddManual}
              disabled={!manualName.trim() || !manualPhone.trim()}
              className="w-full"
            >
              <UserPlus className="w-3.5 h-3.5 mr-1.5" />
              Add
            </Button>
          </div>
        ) : (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setShowManual(true)}
            className="w-full gap-2 text-muted-foreground"
          >
            <Smartphone className="w-3.5 h-3.5" />
            Add by phone number
          </Button>
        )}

        {/* Done button */}
        <Button onClick={handleDone} disabled={totalCount === 0} className="w-full">
          {totalCount > 0 ? `Add ${totalCount} ${totalCount === 1 ? "person" : "people"}` : "Select people"}
        </Button>
      </DialogContent>
    </Dialog>
  );
}

function ContactRow({ contact, isSelected, onToggle }: { contact: SavedContact; isSelected: boolean; onToggle: () => void }) {
  return (
    <button
      onClick={onToggle}
      className={`w-full flex items-center gap-3 px-2 py-2 rounded-lg transition-colors text-left ${
        isSelected ? "bg-primary/10" : "hover:bg-muted/60"
      }`}
    >
      <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-foreground shrink-0">
        {contact.avatar_url ? (
          <img src={contact.avatar_url} alt="" className="w-8 h-8 rounded-full object-cover" />
        ) : (
          contact.name.charAt(0).toUpperCase()
        )}
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <p className="text-sm font-medium text-foreground truncate">{contact.name}</p>
          {contact.is_app_user && (
            <span className="text-[9px] font-bold bg-primary/15 text-primary px-1.5 py-0.5 rounded-full shrink-0">
              GN
            </span>
          )}
        </div>
        <p className="text-xs text-muted-foreground">{contact.phone_number}</p>
      </div>
      <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 transition-colors ${
        isSelected ? "bg-primary border-primary" : "border-muted-foreground/30"
      }`}>
        {isSelected && <Check className="w-3 h-3 text-primary-foreground" />}
      </div>
    </button>
  );
}
