interface Props {
  title: string;
  tags: string[];
  colorClass?: string;
}

export function TagFlowSection({ title, tags, colorClass = "bg-primary/10 text-primary" }: Props) {
  if (tags.length === 0) return null;

  return (
    <div className="space-y-2">
      <h4 className="text-[11px] font-bold uppercase tracking-wider text-muted-foreground">{title}</h4>
      <div className="flex flex-wrap gap-1.5">
        {tags.map(tag => (
          <span key={tag} className={`text-xs font-medium px-2.5 py-1 rounded-full ${colorClass}`}>
            {tag}
          </span>
        ))}
      </div>
    </div>
  );
}
