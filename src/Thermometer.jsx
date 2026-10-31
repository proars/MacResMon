// Vertical thermometer. The mercury height and colour follow the temperature
// (green -> yellow -> red); both animate when it changes. `value` is in °C; `unit` ('C' | 'F') only changes the label.
import { temp } from './format.js';
const MIN = 30, MAX = 105;

const hue = (t) => Math.round(Math.max(0, Math.min(1, (t - 40) / 55)) * -130 + 140); // 140 green .. 10 red

export default function Thermometer({ value, unit = 'C' }) {
  const known = value != null && isFinite(value);
  const r = known ? Math.max(0, Math.min(1, (value - MIN) / (MAX - MIN))) : 0;
  const color = known ? `hsl(${hue(value)} 70% 50%)` : 'var(--track)';
  const top = 10, bulb = 100, tube = bulb - 14 - top; // tube spans y=top..bulb-14
  const fillH = tube * r;
  return (
    <div className="thermo" title={known ? temp(value, unit) : 'no data'}>
      <svg viewBox="0 0 40 120">
        <rect x="14" y={top} width="12" height={tube + 8} rx="6" className="thermo-glass" />
        <circle cx="20" cy="104" r="12" className="thermo-glass" />
        <rect x="17" y={top + 4 + tube - fillH} width="6" height={fillH + 8} rx="3" fill={color} className="thermo-fill" />
        <circle cx="20" cy="104" r="8.5" fill={color} className="thermo-bulb" />
        {[0.25, 0.5, 0.75].map((f) => (
          <line key={f} x1="28" x2="33" y1={top + 4 + tube * (1 - f)} y2={top + 4 + tube * (1 - f)} className="thermo-tick" />
        ))}
      </svg>
      <b style={{ color: known ? color : undefined }}>{temp(known ? value : null, unit)}</b>
    </div>
  );
}
