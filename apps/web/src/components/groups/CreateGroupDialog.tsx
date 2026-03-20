import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import { createGroup, addGroupMember } from "@/lib/groupQueries";
import type { GameGroup } from "@/lib/groupTypes";

interface CreateGroupDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onCreated: (group: GameGroup) => void;
}

const GROUP_ICONS = ["🎲", "🃏", "♟️", "🎯", "🏆", "⚔️", "🧩", "🎮", "🎪", "🌟", "🔥", "💎"];

export function CreateGroupDialog({ open, onOpenChange, onCreated }: CreateGroupDialogProps) {
  const [step, setStep] = useState<1 | 2>(1);
  const [name, setName] = useState("");
  const [emoji, setEmoji] = useState("🎲");
  const [description, setDescription] = useState("");
  const [creating, setCreating] = useState(false);
  const [createdGroup, setCreatedGroup] = useState<GameGroup | null>(null);

  // Step 2 member fields
  const [memberName, setMemberName] = useState("");
  const [memberPhone, setMemberPhone] = useState("");
  const [addedMembers, setAddedMembers] = useState<{ name: string; phone: string }[]>([]);

  const reset = () => {
    setStep(1);
    setName("");
    setEmoji("🎲");
    setDescription("");
    setCreatedGroup(null);
    setMemberName("");
    setMemberPhone("");
    setAddedMembers([]);
  };

  const handleCreate = async () => {
    if (!name.trim()) return;
    setCreating(true);
    try {
      const group = await createGroup(name.trim(), emoji, description.trim() || undefined);
      setCreatedGroup(group);
      setStep(2);
      toast.success("Group created!");
    } catch {
      toast.error("Failed to create group");
    } finally {
      setCreating(false);
    }
  };

  const handleAddMember = async () => {
    if (!memberName.trim() || !memberPhone.trim() || !createdGroup) return;
    try {
      await addGroupMember(createdGroup.id, { phone_number: memberPhone.trim(), display_name: memberName.trim() });
      setAddedMembers(prev => [...prev, { name: memberName.trim(), phone: memberPhone.trim() }]);
      setMemberName("");
      setMemberPhone("");
      toast.success("Member added");
    } catch {
      toast.error("Failed to add member");
    }
  };

  const handleDone = () => {
    if (createdGroup) {
      onCreated({ ...createdGroup, members: addedMembers.map((m, i) => ({ id: String(i), group_id: createdGroup.id, user_id: null, phone_number: m.phone, display_name: m.name, tier: 1, sort_order: i, added_at: new Date().toISOString() })) });
    }
    reset();
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={(o) => { if (!o) reset(); onOpenChange(o); }}>
      <DialogContent className="sm:max-w-md">
        {step === 1 ? (
          <>
            <DialogHeader>
              <DialogTitle className="text-base font-bold">Create Group</DialogTitle>
            </DialogHeader>
            <div className="space-y-4 pt-2">
              {/* Icon picker */}
              <div>
                <label className="text-xs font-medium text-muted-foreground mb-2 block">Group Icon</label>
                <div className="grid grid-cols-6 gap-2">
                  {GROUP_ICONS.map(icon => (
                    <button
                      key={icon}
                      onClick={() => setEmoji(icon)}
                      className={`w-10 h-10 rounded-xl flex items-center justify-center text-lg transition-all ${emoji === icon ? "bg-primary/20 ring-2 ring-primary scale-110" : "bg-muted hover:bg-muted/80"}`}
                    >
                      {icon}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground mb-1 block">Group Name</label>
                <Input value={name} onChange={e => setName(e.target.value)} placeholder="Friday Night Crew" />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground mb-1 block">Description (optional)</label>
                <Textarea value={description} onChange={e => setDescription(e.target.value)} placeholder="What's this group about?" rows={2} />
              </div>
              <Button onClick={handleCreate} disabled={!name.trim() || creating} className="w-full">
                {creating ? "Creating…" : "Create"}
              </Button>
            </div>
          </>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle className="text-base font-bold">Add Members</DialogTitle>
            </DialogHeader>
            <div className="space-y-4 pt-2">
              {addedMembers.length > 0 && (
                <div className="space-y-1">
                  {addedMembers.map((m, i) => (
                    <div key={i} className="flex items-center gap-2 text-sm text-foreground py-1">
                      <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center text-[10px] font-bold text-primary">
                        {m.name.charAt(0)}
                      </div>
                      {m.name}
                    </div>
                  ))}
                </div>
              )}
              <div className="flex gap-2">
                <Input value={memberName} onChange={e => setMemberName(e.target.value)} placeholder="Name" className="flex-1" />
                <Input value={memberPhone} onChange={e => setMemberPhone(e.target.value)} placeholder="Phone" className="flex-1" />
              </div>
              <Button variant="outline" onClick={handleAddMember} disabled={!memberName.trim() || !memberPhone.trim()} className="w-full">
                Add Member
              </Button>
              <Button onClick={handleDone} className="w-full">
                {addedMembers.length === 0 ? "Skip" : "Done"}
              </Button>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
