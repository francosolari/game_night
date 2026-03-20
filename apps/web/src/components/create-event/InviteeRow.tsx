import { ArrowDown, ArrowUp, Trash2, User } from "lucide-react";

interface Props {
  name: string;
  phone: string;
  tier: number;
  onBench?: () => void;
  onPromote?: () => void;
  onRemove: () => void;
}

export function InviteeRow({ name, phone, tier, onBench, onPromote, onRemove }: Props) {
  return (
    <div className="flex items-center gap-3 py-2 px-1 group">
      <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0">
        <User className="w-4 h-4 text-muted-foreground" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground truncate">{name}</p>
        <p className="text-xs text-muted-foreground truncate">{phone}</p>
      </div>
      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
        {tier === 1 && onBench && (
          <button onClick={onBench} className="p-1 rounded hover:bg-muted" title="Move to bench">
            <ArrowDown className="w-3.5 h-3.5 text-muted-foreground" />
          </button>
        )}
        {tier === 2 && onPromote && (
          <button onClick={onPromote} className="p-1 rounded hover:bg-muted" title="Promote to playing">
            <ArrowUp className="w-3.5 h-3.5 text-muted-foreground" />
          </button>
        )}
        <button onClick={onRemove} className="p-1 rounded hover:bg-destructive/10">
          <Trash2 className="w-3.5 h-3.5 text-destructive" />
        </button>
      </div>
    </div>
  );
}
