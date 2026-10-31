import { useState, useEffect, useMemo } from 'react';
import { useStream } from './useStream.js';
import { evaluateAlerts } from './alerts.js';
import Ring from './Ring.jsx';
import Thermometer from './Thermometer.jsx';
import Sparkline from './Sparkline.jsx';
import CoolingCard from './CoolingCard.jsx';
import MemoryCard from './Memory.jsx';
import Alerts from './Alerts.jsx';
import PowerBadge from './PowerBadge.jsx';
import MachineButton from './MachineButton.jsx';
import Processes from './Processes.jsx';
import Battery from './Battery.jsx';
import Storage from './Storage.jsx';
import Network from './Network.jsx';
import PowerCard from './Power.jsx';
import { Card, Stat, heat } from './ui.jsx';
import { pct, num, ghz, uptime } from './format.js';

function Cores({ clusters }) {
  return (
    <Card title="CPU cores" wide>
      <div className="clusters">
        {clusters.map((cl, i) => (
          <div key={cl.name || i} className="cluster">
            <div className="row"><b>{cl.name || (i === 0 ? 'Performance' : 'Efficiency')} <span className="muted">· {cl.cores.length} cores</span></b>
              <span className="muted">{pct(cl.load)} · {ghz(cl.freq)}</span></div>
            <div className="cores">
              {cl.cores.map((c) => (
                <div key={c.id} className="core" title={`Core ${c.id}: ${pct(c.activeRatio)} @ ${ghz(c.freq)}`}>
                  <div className="core-fill" style={{ transform: `scaleY(${Math.min(1, Math.max(0.03, c.activeRatio))})`, background: heat(c.activeRatio) }} />
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}

export default function App() {
  const { snap, history, online } = useStream();

  // Temperature unit: set in the app's Settings and sent with every snapshot (menu bar and notifications use it too).
  const unit = snap.unit === 'F' ? 'F' : 'C';

  // The header shows the active alerts; macOS notifications for them come from the native side.
  const alerts = useMemo(() => evaluateAlerts(snap, unit), [snap, unit]);

  // Light/dark toggle; index.html sets the initial value before first paint.
  const [theme, setTheme] = useState(() => (typeof document !== 'undefined' && document.documentElement.dataset.theme) || 'light');
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem('theme', theme); } catch { /* storage blocked */ }
  }, [theme]);

  // The app keeps pushing snapshots (this render runs with each one) even when macmon stalls, so the age of
  // the last sensor frame (sensorTs) tells whether the readings are still fresh.
  const stale = online && snap.sensorTs != null && Date.now() - snap.sensorTs > Math.max(5000, 2.5 * (snap.intervalMs ?? 1000));
  const state = !online ? ['down', 'No data'] : stale ? ['busy', 'Stale'] : ['ok', `Up ${uptime(snap.uptime)}`];

  const series = (k) => history.map((h) => h[k]);
  const clusters = Array.isArray(snap.clusters) ? snap.clusters.filter((c) => c.cores.length) : [];
  const fans = Array.isArray(snap.fans) ? snap.fans : [];
  const waiting = Boolean(snap.error) && snap.cpu == null;

  return (
    <div className="app">
      <header className="topbar">
        <div className="topbar-in">
          <h1>MacRes<span>Mon</span></h1>
          <div className="badges">
            <PowerBadge battery={snap.battery} />
            <Alerts alerts={alerts} />
          </div>
          <div className="tb-right">
            <span className={`badge status ${state[0]}`}><i /> {state[1]}</span>
            <MachineButton m={snap.machine} ram={{ used: snap.ramUsed, total: snap.ramTotal }} disk={snap.disk} />
            <button className="icon-btn" onClick={() => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))} aria-label="Toggle light/dark theme" title="Toggle theme">
              {theme === 'dark' ? '☀️' : '🌙'}
            </button>
          </div>
        </div>
      </header>

      <main>
        <div className="grid">
          {waiting ? (
            <Card title="Hardware" wide><p className="muted">{snap.error || 'Waiting for sensor data…'}</p></Card>
          ) : (
            <>
              <Card title="CPU">
                <div className="gauge">
                  <Ring value={snap.cpu} color={heat(snap.cpu)} label={pct(snap.cpu)} sub="load" />
                  <div className="gauge-side" />
                  <Thermometer value={snap.cpuTemp || null} unit={unit} />
                </div>
                <Sparkline values={series('cpu')} max={1} />
              </Card>
              <Card title="GPU">
                <div className="gauge">
                  <Ring value={snap.gpu} color={heat(snap.gpu)} label={pct(snap.gpu)} sub={ghz(snap.gpuFreq)} />
                  <div className="gauge-side">
                    <Stat label="Power" value={num(snap.gpuPower, 1, ' W')} />
                  </div>
                  <Thermometer value={snap.gpuTemp || null} unit={unit} />
                </div>
                <Sparkline values={series('gpu')} max={1} color="var(--accent2)" />
              </Card>
              <MemoryCard snap={snap} history={history} />

              {clusters.length > 0 && <Cores clusters={clusters} />}

              <div className="half-row">
                <PowerCard snap={snap} history={history} />
                <CoolingCard fans={fans} history={history} />
              </div>

              <Battery battery={snap.battery} />
              <Storage disk={snap.disk} io={snap.diskIO} history={history} />
              <Network net={snap.net} history={history} />
              <Processes procs={snap.procs} />
            </>
          )}
        </div>
      </main>
    </div>
  );
}
