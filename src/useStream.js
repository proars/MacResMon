import { useState, useEffect } from 'react';

// Live data for the dashboard. The native app (Swift) pushes two kinds of events into window.__nativeHub:
//   `history`   once: the full rolling window (60 samples, one per update interval)
//   `snapshot`  every update interval (1 s by default): the readings, whose `point` is the newest history sample
const MAX_HISTORY = 60;

export function useStream() {
  const [snap, setSnap] = useState({ error: 'Waiting for data…' });
  const [history, setHistory] = useState([]);
  const hub = typeof window !== 'undefined' ? window.__nativeHub : undefined;

  useEffect(() => {
    if (!hub) {
      setSnap({ error: 'This interface runs inside the MacResMon app: build and open it with `npm run native:build`.' });
      return undefined;
    }
    return hub.subscribe((type, data) => {
      if (type === 'history') {
        if (Array.isArray(data)) setHistory(data.slice(-MAX_HISTORY));
        return;
      }
      setSnap(data);
      const p = data?.point;
      if (p) setHistory((h) => (h.length && h[h.length - 1].ts === p.ts ? h : [...h, p].slice(-MAX_HISTORY)));
    });
  }, [hub]);

  return { snap, history, online: Boolean(hub) };
}

export default useStream;
