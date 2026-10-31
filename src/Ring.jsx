// Circular gauge. `value` is 0..1.
export default function Ring({ value, color, label, sub }) {
  const r = 48, c = 2 * Math.PI * r, v = Math.max(0, Math.min(1, value ?? 0));
  return (
    <div className="ring">
      <svg viewBox="0 0 120 120">
        <circle cx="60" cy="60" r={r} className="ring-track" />
        <circle cx="60" cy="60" r={r} className="ring-val" stroke={color}
          strokeDasharray={`${c * v} ${c}`} transform="rotate(-90 60 60)" />
      </svg>
      <div className="ring-text"><b>{label}</b>{sub && <small>{sub}</small>}</div>
    </div>
  );
}
