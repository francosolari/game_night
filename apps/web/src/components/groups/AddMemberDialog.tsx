import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { addGroupMember } from "@/lib/groupQueries";

interface AddMemberDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  groupId: string;
  onAdded: () => void;
}

export function AddMemberDialog({ open, onOpenChange, groupId, onAdded }: AddMemberDialogProps) {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [adding, setAdding] = useState(false);

  const handleAdd = async () => {
    if (!name.trim() || !phone.trim()) return;
    setAdding(true);
    try {
      await addGroupMember(groupId, { phone_number: phone.trim(), display_name: name.trim() });
      toast.success("Member added");
      setName("");
      setPhone("");
      onAdded();
      onOpenChange(false);
    } catch {
      toast.error("Failed to add member");
    } finally {
      setAdding(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle className="text-base font-bold">Add Member</DialogTitle>
        </DialogHeader>
        <div className="space-y-3 pt-2">
          <Input value={name} onChange={e => setName(e.target.value)} placeholder="Name" />
          <Input value={phone} onChange={e => setPhone(e.target.value)} placeholder="Phone number" />
          <Button onClick={handleAdd} disabled={!name.trim() || !phone.trim() || adding} className="w-full">
            {adding ? "Adding…" : "Add"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
