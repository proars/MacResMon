import { Card, Stat } from './ui.jsx';
import Sparkline from './Sparkline.jsx';
import { num } from './format.js';

// Whole-system power (SMC) with its trend, plus the chip part (CPU + GPU + ANE + RAM) and its CPU and GPU shares.
export default function PowerCard({ snap = {}, history = [] }) {
  return (
    <Card title="Power" right="whole system">
      <div className="big">{num(snap.sysPower, 1, ' W')}</div>
      <Sparkline values={history.map((h) => h.power)} />
      <Stat label="Chip power" value={num(snap.chipPower, 1, ' W')} />
      <Stat label="CPU power" value={num(snap.cpuPower, 1, ' W')} />
      <Stat label="GPU power" value={num(snap.gpuPower, 1, ' W')} />
    </Card>
  );
}
