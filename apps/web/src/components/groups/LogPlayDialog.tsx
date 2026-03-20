import { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { supabase } from "@/lib/supabase";
import { createPlay } from "@/lib/groupQueries";
import type { Game } from "@/lib/types";
import type { GroupMember } from "@/lib/groupTypes";

interface LogPlayDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  groupId: string;
  members: GroupMember[];
  onLogged: () => void;
}

interface ParticipantDraft {
  memberId: string;
  name: string;
  userId?: string | null;
  phone?: string;
  playing: boolean;
  isWinner: boolean;
}

export function LogPlayDialog({ open, onOpenChange, groupId, members, onLogged }: LogPlayDialogProps) {
  const [games, setGames] = useState<Game[]>([]);
  const [selectedGameId, setSelectedGameId] = useState<string | null>(null);
  const [isCooperative, setIsCooperative] = useState(false);
  const [coopResult, setCoopResult] = useState<"won" | "lost">("won");
  const [participants, setParticipants] = useState<ParticipantDraft[]>([]);
  const [saving, setSaving] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    if (!open) return;
    // Load user's game library
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;
      const { data } = await supabase
        .from("game_library")
        .select("game_id, game:games(*)")
        .eq("user_id", user.id);
      if (data) {
        setGames(data.map((d: any) => d.game).filter(Boolean) as Game[]);
      }
    })();

    // Pre-fill participants from members
    setParticipants(members.map(m => ({
      memberId: m.id,
      name: m.display_name || "Unknown",
      userId: m.user_id,
      phone: m.phone_number,
      playing: true,
      isWinner: false,
    })));
  }, [open, members]);

  const filteredGames = searchQuery
    ? games.filter(g => g.name.toLowerCase().includes(searchQuery.toLowerCase()))
    : games;

  const handleSave = async () => {
    if (!selectedGameId) return;
    setSaving(true);
    try {
      await createPlay({
        group_id: groupId,
        game_id: selectedGameId,
        is_cooperative: isCooperative,
        cooperative_result: isCooperative ? coopResult : null,
        participants: participants
          .filter(p => p.playing)
          .map(p => ({
            display_name: p.name,
            user_id: p.userId ?? undefined,
            phone_number: p.phone,
            is_winner: p.isWinner,
          })),
      });
      toast.success("Play logged!");
      onLogged();
      onOpenChange(false);
    } catch {
      toast.error("Failed to log play");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="text-base font-bold">Log a Play</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 pt-2">
          {/* Game selection */}
          <div>
            <label className="text-xs font-medium text-muted-foreground mb-1 block">Game</label>
            <Input value={searchQuery} onChange={e => setSearchQuery(e.target.value)} placeholder="Search your library…" className="mb-2" />
            <div className="max-h-32 overflow-y-auto space-y-1 border border-border/50 rounded-lg p-1">
              {filteredGames.length === 0 ? (
                <p className="text-xs text-muted-foreground p-2">No games found</p>
              ) : (
                filteredGames.slice(0, 20).map(g => (
                  <button
                    key={g.id}
                    onClick={() => { setSelectedGameId(g.id); setSearchQuery(g.name); }}
                    className={`w-full text-left flex items-center gap-2 px-2 py-1.5 rounded-md text-sm transition-colors ${selectedGameId === g.id ? "bg-primary/10 text-primary" : "hover:bg-muted"}`}
                  >
                    {g.thumbnail_url && <img src={g.thumbnail_url} alt="" className="w-6 h-6 rounded object-cover" />}
                    <span className="truncate">{g.name}</span>
                  </button>
                ))
              )}
            </div>
          </div>

          {/* Cooperative toggle */}
          <div className="flex items-center justify-between">
            <Label className="text-xs font-medium">Cooperative Game</Label>
            <Switch checked={isCooperative} onCheckedChange={setIsCooperative} />
          </div>
          {isCooperative && (
            <div className="flex gap-2">
              <Button variant={coopResult === "won" ? "default" : "outline"} size="sm" onClick={() => setCoopResult("won")}>Victory</Button>
              <Button variant={coopResult === "lost" ? "default" : "outline"} size="sm" onClick={() => setCoopResult("lost")}>Defeat</Button>
            </div>
          )}

          {/* Participants */}
          <div>
            <label className="text-xs font-medium text-muted-foreground mb-2 block">Participants</label>
            <div className="space-y-2">
              {participants.map((p, i) => (
                <div key={p.memberId} className="flex items-center gap-3">
                  <Checkbox
                    checked={p.playing}
                    onCheckedChange={(c) => {
                      const updated = [...participants];
                      updated[i] = { ...updated[i], playing: !!c };
                      setParticipants(updated);
                    }}
                  />
                  <span className="text-sm flex-1 truncate">{p.name}</span>
                  {!isCooperative && p.playing && (
                    <label className="flex items-center gap-1 text-xs text-muted-foreground">
                      <Checkbox
                        checked={p.isWinner}
                        onCheckedChange={(c) => {
                          const updated = [...participants];
                          updated[i] = { ...updated[i], isWinner: !!c };
                          setParticipants(updated);
                        }}
                      />
                      Winner
                    </label>
                  )}
                </div>
              ))}
            </div>
          </div>

          <Button onClick={handleSave} disabled={!selectedGameId || saving} className="w-full">
            {saving ? "Saving…" : "Log Play"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
