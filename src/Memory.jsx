import { Card, Stat, heat } from './ui.jsx';
import Ring from './Ring.jsx';
import Sparkline from './Sparkline.jsx';
import { gb, pct } from './format.js';

// Unified memory: usage ring, totals, swap, and the usage trend.
export default function MemoryCard({ snap = {}, history = [] }) {
  const ratio = snap.ramTotal ? (snap.ramUsed ?? 0) / snap.ramTotal : 0;
  return (
    <Card title="Memory" right="unified">
      <div className="gauge">
        <Ring value={ratio} color={heat(ratio)} label={pct(ratio)} sub={gb(snap.ramUsed)} />
        <div className="gauge-side">
          <Stat label="Total" value={gb(snap.ramTotal)} />
          <Stat label="Swap" value={`${gb(snap.swapUsed)} / ${gb(snap.swapTotal)}`} />
        </div>
      </div>
      <Sparkline values={history.map((h) => h.ram)} max={snap.ramTotal} color="var(--accent3)" />
    </Card>
  );
}
