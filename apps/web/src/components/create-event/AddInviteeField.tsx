import { useState } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Plus } from "lucide-react";

interface Props {
  onAdd: (name: string, phone: string) => void;
}

export function AddInviteeField({ onAdd }: Props) {
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");

  const handleAdd = () => {
    if (!phone.trim()) return;
    onAdd(name.trim() || phone.trim(), phone.trim());
    setName("");
    setPhone("");
  };

  return (
    <div className="flex gap-2 items-end">
      <div className="flex-1 space-y-1">
        <Input
          placeholder="Name"
          value={name}
          onChange={e => setName(e.target.value)}
          className="h-9 text-sm"
        />
      </div>
      <div className="flex-1 space-y-1">
        <Input
          placeholder="Phone number"
          value={phone}
          onChange={e => setPhone(e.target.value)}
          onKeyDown={e => e.key === "Enter" && handleAdd()}
          className="h-9 text-sm"
          type="tel"
        />
      </div>
      <Button size="icon" variant="outline" onClick={handleAdd} className="h-9 w-9 shrink-0">
        <Plus className="w-4 h-4" />
      </Button>
    </div>
  );
}
