import { cn } from "@/lib/utils";

interface Props {
  rating: number;
  size?: "sm" | "lg";
  className?: string;
}

function ratingColor(rating: number): string {
  if (rating >= 8.5) return "bg-green-600 text-white";
  if (rating >= 7.0) return "bg-lime-600 text-white";
  if (rating >= 4.0) return "bg-amber-500 text-white";
  return "bg-red-500 text-white";
}

export function RatingBadge({ rating, size = "sm", className }: Props) {
  const dims = size === "lg" ? "px-3 py-1.5 text-sm" : "px-2 py-0.5 text-[10px]";
  return (
    <span className={cn("font-extrabold rounded-lg inline-flex items-center", dims, ratingColor(rating), className)}>
      ★ {rating.toFixed(1)}
    </span>
  );
}
