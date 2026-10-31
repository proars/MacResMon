import { temp, pct } from './format.js';

// Alert thresholds.
const LIMITS = { temp: 90, tempCritical: 100, fan: 0.95, mem: 0.9, memCritical: 0.95, battery: 10, batteryCritical: 5, diskFree: 0.1 };

// Active alerts for a snapshot: [{ id, level: 'warning' | 'critical', text }]. `id` is stable
// while the condition lasts, so a notification fires once when it appears.
export function evaluateAlerts(s = {}, unit = 'C') {
  const out = [];
  for (const [id, label, t] of [['cpu-temp', 'CPU', s.cpuTemp], ['gpu-temp', 'GPU', s.gpuTemp]]) {
    if (t >= LIMITS.temp) out.push({ id, level: t >= LIMITS.tempCritical ? 'critical' : 'warning', text: `${label} is hot: ${temp(t, unit)}` });
  }
  (Array.isArray(s.fans) ? s.fans : []).forEach((f, i) => {
    if (f.max > 0 && f.rpm / f.max >= LIMITS.fan) out.push({ id: `fan-${i}`, level: 'warning', text: `Fan ${i + 1} is at its maximum (${Math.round(f.rpm)} rpm)` });
  });
  if (s.ramTotal > 0) {
    const r = s.ramUsed / s.ramTotal;
    if (r >= LIMITS.mem) out.push({ id: 'mem', level: r >= LIMITS.memCritical ? 'critical' : 'warning', text: `Memory is ${pct(r)} full` });
  }
  const b = s.battery;
  if (b?.onBattery && b.percent <= LIMITS.battery) out.push({ id: 'battery', level: b.percent <= LIMITS.batteryCritical ? 'critical' : 'warning', text: `Battery is low: ${b.percent}%` });
  const d = s.disk;
  if (d?.total > 0 && d.free / d.total <= LIMITS.diskFree) out.push({ id: 'disk', level: 'warning', text: `Disk is almost full: ${pct(d.free / d.total)} free` });
  return out;
}
