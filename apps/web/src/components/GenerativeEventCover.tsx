import { useMemo } from "react";

interface GenerativeEventCoverProps {
  title: string;
  eventId: string;
  variant?: number;
  className?: string;
}

// Color schemes matching iOS GenerativeEventCover
const COLOR_SCHEMES = [
  { bg: ["hsl(94 19% 48%)", "hsl(94 19% 56%)"], text: "hsl(18 47% 53%)" },         // sage → terracotta
  { bg: ["hsl(18 47% 53%)", "hsl(18 47% 62%)"], text: "hsl(94 19% 41%)" },          // terracotta → sageDark
  { bg: ["hsl(210 18% 55%)", "hsl(210 12% 40%)"], text: "hsl(27 38% 13%)" },        // dusty blue
  { bg: ["hsl(330 22% 45%)", "hsl(315 28% 31%)"], text: "hsl(330 60% 88%)" },       // warm plum
  { bg: ["hsl(155 100% 21%)", "hsl(100 18% 42%)"], text: "hsl(35 80% 62%)" },       // forest → moss
  { bg: ["hsl(22 32% 50%)", "hsl(25 42% 42%)"], text: "hsl(94 19% 41%)" },          // clay → copper
  { bg: ["hsl(270 16% 47%)", "hsl(267 30% 55%)"], text: "hsl(18 47% 62%)" },        // dusk → lavender
  { bg: ["hsl(190 30% 42%)", "hsl(180 100% 36%)"], text: "hsl(22 32% 50%)" },       // ocean → teal
  { bg: ["hsl(8 75% 40%)", "hsl(330 22% 45%)"], text: "hsl(330 60% 88%)" },         // burgundy
  { bg: ["hsl(185 67% 22%)", "hsl(155 100% 21%)"], text: "hsl(72 85% 72%)" },       // deep teal → forest
  { bg: ["hsl(0 0% 23%)", "hsl(210 12% 40%)"], text: "hsl(180 100% 36%)" },         // charcoal
  { bg: ["hsl(84 16% 58%)", "hsl(100 18% 42%)"], text: "hsl(8 75% 40%)" },          // olive → moss
  { bg: ["hsl(267 30% 55%)", "hsl(330 60% 88%)"], text: "hsl(315 28% 31%)" },       // lavender → blush
  { bg: ["hsl(37 91% 62%)", "hsl(22 32% 50%)"], text: "hsl(80 22% 21%)" },          // orange → clay
  { bg: ["hsl(180 100% 36%)", "hsl(190 30% 42%)"], text: "hsl(37 91% 62%)" },       // teal → ocean
  { bg: ["hsl(80 22% 21%)", "hsl(0 0% 23%)"], text: "hsl(72 85% 72%)" },            // espresso → charcoal
];

const PATTERNS = ["diagonal", "circles", "grid", "chevrons", "dots"] as const;

function stableHash(id: string, variant: number): number {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = ((hash << 5) - hash + id.charCodeAt(i)) | 0;
  }
  return Math.abs(hash + variant);
}

export function GenerativeEventCover({ title, eventId, variant = 0, className = "" }: GenerativeEventCoverProps) {
  const seed = useMemo(() => stableHash(eventId, variant), [eventId, variant]);
  const scheme = COLOR_SCHEMES[seed % COLOR_SCHEMES.length];
  const pattern = PATTERNS[seed % PATTERNS.length];
  const displayTitle = title || "Game Night";
  const rotation = [-8, -5, -3, 0, 3, 5, 8, -12, 6][Math.floor(seed / 7) % 9];

  return (
    <div
      className={`relative overflow-hidden ${className}`}
      style={{
        background: `linear-gradient(135deg, ${scheme.bg[0]} 0%, ${scheme.bg[1]} 100%)`,
      }}
    >
      {/* Pattern layer */}
      <svg className="absolute inset-0 w-full h-full opacity-15" aria-hidden="true">
        <PatternSVG pattern={pattern} color={scheme.bg[0]} seed={seed} />
      </svg>

      {/* Title decoration */}
      <div className="absolute inset-0 flex items-center justify-center">
        <span
          className="text-center font-black uppercase leading-none select-none"
          style={{
            color: scheme.text,
            opacity: 0.42,
            fontSize: `clamp(1rem, ${Math.min(6 / Math.max(displayTitle.length, 1), 0.38) * 100}%, 3rem)`,
            transform: `rotate(${rotation}deg)`,
            maxWidth: "115%",
            lineHeight: 0.95,
            wordBreak: "break-word",
          }}
        >
          {displayTitle.toUpperCase()}
        </span>
      </div>
    </div>
  );
}

function PatternSVG({ pattern, color, seed }: { pattern: string; color: string; seed: number }) {
  switch (pattern) {
    case "diagonal":
      return (
        <>
          {Array.from({ length: 20 }, (_, i) => (
            <line
              key={i}
              x1={i * 24}
              y1={0}
              x2={i * 24 - 200}
              y2={200}
              stroke={color}
              strokeWidth={7}
            />
          ))}
        </>
      );
    case "circles": {
      const cx = ((seed % 3 + 1) / 4) * 100 + "%";
      const cy = (((Math.floor(seed / 3)) % 3 + 1) / 4) * 100 + "%";
      return (
        <>
          {Array.from({ length: 8 }, (_, i) => (
            <circle key={i} cx={cx} cy={cy} r={(i + 1) * 20} fill="none" stroke={color} strokeWidth={2} />
          ))}
        </>
      );
    }
    case "grid":
      return (
        <>
          {Array.from({ length: 200 }, (_, i) => {
            const x = (i % 20) * 20 + 4;
            const y = Math.floor(i / 20) * 20 + 4;
            return <rect key={i} x={x} y={y} width={12} height={12} rx={3} fill={color} />;
          })}
        </>
      );
    case "chevrons":
      return (
        <>
          {Array.from({ length: 12 }, (_, i) => (
            <polyline
              key={i}
              points={`0,${i * 24} 200,${i * 24 - 12} 400,${i * 24}`}
              fill="none"
              stroke={color}
              strokeWidth={2}
            />
          ))}
        </>
      );
    case "dots":
      return (
        <>
          {Array.from({ length: 200 }, (_, i) => {
            const x = (i % 20) * 16 + 8;
            const y = Math.floor(i / 20) * 16 + 8;
            return <circle key={i} cx={x} cy={y} r={3} fill={color} />;
          })}
        </>
      );
    default:
      return null;
  }
}
