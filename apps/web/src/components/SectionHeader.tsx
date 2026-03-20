interface SectionHeaderProps {
  title: string;
  action?: string;
  onAction?: () => void;
}

export function SectionHeader({ title, action, onAction }: SectionHeaderProps) {
  return (
    <div className="flex items-center justify-between">
      <h2 className="text-lg font-bold text-foreground">{title}</h2>
      {action && onAction && (
        <button
          onClick={onAction}
          className="text-sm font-medium text-primary hover:text-primary/80 transition-colors active:scale-[0.97]"
        >
          {action}
        </button>
      )}
    </div>
  );
}
