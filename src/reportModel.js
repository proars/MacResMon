// Reports: pure helpers behind Reports.jsx (rows, totals, cost, formatting). The data comes from the app
// (window.__native.request('reports.get')); cost is energy x the price from Settings, so a new price re-costs all days.

export const RANGES = [7, 14, 30, 90, 0]; // days; 0 = all
export const rangeLabel = (r) => (r === 0 ? 'All' : `${r} days`);

export const dayKey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

// First day ("YYYY-MM-DD") of a range ending today, or null for all. Today counts as day 1.
export function fromKey(range, now = new Date()) {
  if (!range) return null;
  return dayKey(new Date(now.getFullYear(), now.getMonth(), now.getDate() - range + 1));
}

export const costOf = (energyJ, price) => (energyJ / 3.6e6) * price;

// Day rows (newest first) and the total row for the days since `from`.
export function buildRows(days, from, price) {
  const rows = days.filter((d) => !from || d.day >= from).map((d) => ({
    day: d.day, energyJ: d.energyJ, seconds: d.seconds, peakW: d.peakW, spikes: d.spikes, maxTempC: d.maxTempC,
    avgW: d.seconds > 0 ? d.energyJ / d.seconds : null, cost: costOf(d.energyJ, price),
  }));
  rows.sort((a, b) => (a.day < b.day ? 1 : -1));
  const energyJ = rows.reduce((s, r) => s + r.energyJ, 0);
  const seconds = rows.reduce((s, r) => s + r.seconds, 0);
  const temps = rows.map((r) => r.maxTempC).filter((t) => t != null);
  const total = {
    energyJ, seconds, peakW: rows.reduce((m, r) => Math.max(m, r.peakW), 0), spikes: rows.reduce((s, r) => s + r.spikes, 0),
    maxTempC: temps.length ? Math.max(...temps) : null, avgW: seconds > 0 ? energyJ / seconds : null, cost: costOf(energyJ, price),
  };
  return { rows, total };
}

// Spikes (newest first) that started on or after `from`.
export function filterSpikes(spikes, from) {
  return spikes.filter((s) => !from || dayKey(new Date(s.start)) >= from).sort((a, b) => b.start - a.start);
}

export const energy = (j) => (j == null ? '–' : j >= 3.6e6 ? `${(j / 3.6e6).toFixed(2)} kWh` : `${(j / 3600).toFixed(1)} Wh`);
export const watts = (w) => (w == null ? '–' : `${w.toFixed(1)} W`);
export const money = (v, cur = '$') => `${cur}${v >= 1 ? v.toFixed(2) : v.toFixed(3)}`;
export const temp = (c, unit = 'C') => (c == null ? '–' : unit === 'F' ? `${Math.round(c * 9 / 5 + 32)}°F` : `${Math.round(c)}°C`);

export function duration(ms) {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return `${s} s`;
  if (s < 3600) return `${Math.floor(s / 60)} min ${String(s % 60).padStart(2, '0')} s`;
  return `${Math.floor(s / 3600)} h ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')} min`;
}

export const stamp = (ms) => {
  const d = new Date(ms);
  return `${dayKey(d)} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
};
