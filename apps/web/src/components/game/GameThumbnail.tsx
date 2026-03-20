import { Dice5 } from "lucide-react";
import { cn } from "@/lib/utils";

interface Props {
  src?: string | null;
  name: string;
  size?: "sm" | "md" | "lg" | "xl";
  className?: string;
}

const sizeMap = {
  sm: "w-8 h-8 rounded",
  md: "w-14 h-14 rounded-lg",
  lg: "w-20 h-20 rounded-xl",
  xl: "w-full aspect-square rounded-xl",
};

const iconMap = {
  sm: "w-3.5 h-3.5",
  md: "w-5 h-5",
  lg: "w-7 h-7",
  xl: "w-10 h-10",
};

export function GameThumbnail({ src, name, size = "md", className }: Props) {
  if (src) {
    return (
      <img
        src={src}
        alt={name}
        className={cn(sizeMap[size], "object-cover shrink-0", className)}
        loading="lazy"
      />
    );
  }
  return (
    <div className={cn(sizeMap[size], "bg-muted flex items-center justify-center shrink-0", className)}>
      <Dice5 className={cn(iconMap[size], "text-muted-foreground")} />
    </div>
  );
}
