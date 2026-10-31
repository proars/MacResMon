// Minimal SVG area chart with 1..N lines on one scale.
//   values: number[]                 -> one line
//   lines:  [{ values, color }]      -> several lines
// `max` fixes the Y scale (else auto). Fill opacity is shared between the lines (min 0.06).
export default function Sparkline({ values, lines, max, color = 'var(--accent)', height = 56 }) {
  const w = 300;
  const all = (lines ?? [{ values, color }]).filter((l) => (l.values || []).filter((x) => x != null).length >= 2);
  if (!all.length) return <svg className="spark" viewBox={`0 0 ${w} ${height}`} />;
  const top = max ?? Math.max(1e-9, ...all.flatMap((l) => l.values.filter((x) => x != null)));
  const opacity = Math.max(0.06, 0.15 / all.length);
  return (
    <svg className="spark" viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none">
      {all.map((l, k) => {
        const step = w / (l.values.length - 1);
        const pts = l.values.map((x, i) => `${(i * step).toFixed(1)},${(height - (Math.min(x ?? 0, top) / top) * (height - 4) - 2).toFixed(1)}`);
        return (
          <g key={k}>
            <polygon points={`0,${height} ${pts.join(' ')} ${w},${height}`} fill={l.color} opacity={opacity} />
            <polyline points={pts.join(' ')} fill="none" stroke={l.color} strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
          </g>
        );
      })}
    </svg>
  );
}
