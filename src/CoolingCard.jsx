import { Card } from './ui.jsx';
import Fan from './Fan.jsx';
import Sparkline from './Sparkline.jsx';
import FanLegend from './FanLegend.jsx';
import { fanColor } from './fanColors.js';

// Cooling: a spinning rotor per fan, one filled speed-trend graph with a line per
// fan (from the rolling `history`), and a legend with the same line colors.
export default function CoolingCard({ fans = [], history = [] }) {
  const right = `${fans.length} ${fans.length === 1 ? 'fan' : 'fans'} detected via SMC`;
  if (!fans.length) {
    return <Card title="Cooling" right={right}><p className="muted">No fans reported (fanless Mac, or macmon is not delivering data).</p></Card>;
  }
  const maxRpm = Math.max(1, ...fans.map((f) => f.max || 0));
  const lines = fans.map((_, i) => ({ values: history.map((h) => h?.fans?.[i]?.rpm ?? 0), color: fanColor(i) }));
  return (
    <Card title="Cooling" right={right}>
      <div className="fan-row">
        {fans.map((f, i) => <Fan key={f.name || i} rpm={f.rpm} max={f.max} label={`Fan ${i + 1}`} />)}
      </div>
      <Sparkline lines={lines} max={maxRpm} height={64} />
      <FanLegend fans={fans} />
    </Card>
  );
}
