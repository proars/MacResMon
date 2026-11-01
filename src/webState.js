// Small UI choices that must survive a relaunch (theme, tab, report period). The app keeps them in its own
// settings (window.__webState is filled before the page loads, state.set saves); localStorage is only the fallback
// for a plain browser, where the page is opened without the app.
export function getState(key, fallback = null) {
  try { const v = window.__webState?.[key]; if (v != null) return v; } catch { /* no app */ }
  try { return localStorage.getItem(key) ?? fallback; } catch { return fallback; }
}

export function setState(key, value) {
  const v = String(value);
  try { if (window.__webState) window.__webState[key] = v; } catch { /* no app */ }
  try { window.__native?.request('state.set', { key, value: v }); } catch { /* no app */ }
  try { localStorage.setItem(key, v); } catch { /* storage blocked */ }
}
