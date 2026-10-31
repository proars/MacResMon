// A titled card; `right` is a muted note on the right of the title, `wide` spans the whole row.
export function Card({ title, right, children, wide }) {
  return (
    <section className={`card${wide ? ' wide' : ''}`}>
      <div className="card-head"><h2>{title}</h2>{right && <span className="muted">{right}</span>}</div>
      {children}
    </section>
  );
}

export function Bar({ value, color = 'var(--accent)' }) {
  return <div className="bar"><div style={{ transform: `scaleX(${Math.min(1, Math.max(0, value))})`, background: color }} /></div>;
}

export function Stat({ label, value }) {
  return <div className="stat"><span>{label}</span><b>{value}</b></div>;
}

// Green -> amber -> red as a load/fill ratio climbs.
export const heat = (r) => (r > 0.85 ? 'var(--bad)' : r > 0.6 ? 'var(--warn)' : 'var(--good)');
