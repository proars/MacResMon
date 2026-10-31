const GB = 1024 ** 3;
export const gb = (b) => (b == null ? '–' : (b / GB).toFixed(b >= 10 * GB ? 0 : 1) + ' GB');
export const pct = (r) => (r == null ? '–' : Math.round(r * 100) + '%');
export const num = (n, d = 1, u = '') => (n == null || !isFinite(n) ? '–' : n.toFixed(d) + u);
export const ghz = (mhz) => (mhz ? (mhz / 1000).toFixed(2) + ' GHz' : 'idle');

// How long the app has been running, from seconds: "<1m", "12m", "2h 14m", "3d 4h".
export const uptime = (s) => {
  if (s == null || !isFinite(s) || s < 0) return '–';
  const m = Math.floor(s / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
  if (d) return `${d}d ${h % 24}h`;
  if (h) return `${h}h ${m % 60}m`;
  return m ? `${m}m` : '<1m';
};

// Temperature from °C in the chosen unit ('C' | 'F').
export const temp = (c, unit = 'C') =>
  c == null || !isFinite(c) ? '–' : unit === 'F' ? Math.round((c * 9) / 5 + 32) + '°F' : Math.round(c) + '°C';

// Megabits per second from bytes per second (network speeds are quoted in decimal bits).
export const mbps = (v) => {
  if (v == null || !isFinite(v)) return '–';
  const m = (v * 8) / 1e6;
  return (m < 10 ? m.toFixed(2) : m < 100 ? m.toFixed(1) : Math.round(m)) + ' Mbps';
};

// Bytes per second.
export const bps = (v) => {
  if (v == null || !isFinite(v)) return '–';
  if (v < 1024) return Math.round(v) + ' B/s';
  if (v < 1024 ** 2) return (v / 1024).toFixed(v < 10240 ? 1 : 0) + ' KB/s';
  if (v < 1024 ** 3) return (v / 1024 ** 2).toFixed(v < 10 * 1024 ** 2 ? 1 : 0) + ' MB/s';
  return (v / 1024 ** 3).toFixed(1) + ' GB/s';
};
