import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (date: Date, startTime: string, endTime: string | null) => void;
  initialDate?: Date;
  initialStartTime?: string;
  initialEndTime?: string | null;
  title?: string;
}

export function DateTimePickerDialog({
  open,
  onOpenChange,
  onSave,
  initialDate,
  initialStartTime = "19:00",
  initialEndTime = null,
  title = "Pick Date & Time",
}: Props) {
  const [date, setDate] = useState<Date>(initialDate || new Date());
  const [startTime, setStartTime] = useState(initialStartTime);
  const [endTime, setEndTime] = useState(initialEndTime || "22:00");
  const [showEnd, setShowEnd] = useState(!!initialEndTime);

  const handleSave = () => {
    onSave(date, startTime, showEnd ? endTime : null);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <Calendar
            mode="single"
            selected={date}
            onSelect={(d) => d && setDate(d)}
            className={cn("p-3 pointer-events-auto mx-auto")}
          />

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label className="text-xs">Start Time</Label>
              <input
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
              />
            </div>
            {showEnd && (
              <div className="space-y-1.5">
                <Label className="text-xs">End Time</Label>
                <input
                  type="time"
                  value={endTime}
                  onChange={(e) => setEndTime(e.target.value)}
                  className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                />
              </div>
            )}
          </div>

          <div className="flex items-center justify-between">
            <Label className="text-sm">End time</Label>
            <Switch checked={showEnd} onCheckedChange={setShowEnd} />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleSave}>Save</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
