import { useState, useCallback } from 'react';

// useState persisted in localStorage (per-viewer preference); works when storage is blocked.
export function usePref(key, initial) {
  const [value, setValue] = useState(() => {
    try {
      const raw = localStorage.getItem('pref.' + key);
      return raw == null ? initial : JSON.parse(raw);
    } catch { return initial; }
  });
  const set = useCallback((v) => {
    setValue(v);
    try { localStorage.setItem('pref.' + key, JSON.stringify(v)); } catch { /* storage blocked */ }
  }, [key]);
  return [value, set];
}

export default usePref;
