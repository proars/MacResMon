import { fanColor } from './fanColors.js';

// Live legend: graph line color, fan name, current RPM and share of the fan's maximum.
export default function FanLegend({ fans = [] }) {
  if (!fans.length) return null;
  return (
    <div className="legend">
      {fans.map((f, i) => (
        <span key={f.name || i} className="legend-item">
          <i className="swatch" style={{ background: fanColor(i) }} />
          <span className="muted">Fan {i + 1}</span>
          <b>{Math.round(f.rpm || 0)} rpm</b>
          {f.max > 0 && <span className="muted">{Math.round(((f.rpm || 0) / f.max) * 100)}%</span>}
        </span>
      ))}
    </div>
  );
}
