const BLADES = 9;
const MAX_REV_PER_SEC = 2.5; // visual speed at full rpm; real 5000+ rpm would just look like a blur

// Blade outline in a 100x100 box, hub at (50,50): a curved paddle pointing up.
const BLADE = 'M50 50 C 40 38, 36 22, 46 9 C 54 6, 63 9, 64 14 C 60 28, 58 40, 50 50 Z';

// Fan: the rotor turns at a speed proportional to rpm/max and stops at 0 rpm; the ring shows rpm/max.
export default function Fan({ rpm, max, label }) {
  const r = Math.round(rpm || 0);
  const ratio = max ? Math.min(1, r / max) : 0;
  // Revolutions per second, rounded to 0.25: the spin is a plain CSS animation (the browser runs it on its own
  // layer, with no script), and changing its duration makes the rotor jump, so it should change rarely.
  const rps = r > 0 ? Math.max(0.25, Math.round(Math.max(0.15, ratio) * MAX_REV_PER_SEC * 4) / 4) : 0;
  const color = ratio > 0.8 ? 'var(--bad)' : ratio > 0.5 ? 'var(--warn)' : 'var(--accent)';
  return (
    <div className="fan">
      {/* Two stacked layers: the static dial, and the rotor (an HTML wrapper, which browsers animate cheaply). */}
      <div className="fan-dial">
        <svg viewBox="0 0 100 100" aria-label={`${label}, ${r} rpm`}>
          <circle cx="50" cy="50" r="48" className="fan-case" />
          <circle cx="50" cy="50" r="46" className="fan-ring" stroke={color}
            strokeDasharray={`${2 * Math.PI * 46 * ratio} ${2 * Math.PI * 46}`} transform="rotate(-90 50 50)" />
        </svg>
        <div className="fan-rotor" aria-hidden="true"
          style={{ animationDuration: rps ? `${1 / rps}s` : '1s', animationPlayState: rps ? 'running' : 'paused' }}>
          <svg viewBox="0 0 100 100">
            {Array.from({ length: BLADES }, (_, i) => (
              <path key={i} d={BLADE} className="fan-blade" fill={color} transform={`rotate(${(360 / BLADES) * i} 50 50)`} />
            ))}
            <circle cx="50" cy="50" r="9" className="fan-hub" />
          </svg>
        </div>
      </div>
      <div className="fan-text">
        <span className="muted">{label}</span>
        <b>{r > 0 ? `${r} rpm` : 'stopped'}</b>
      </div>
    </div>
  );
}
