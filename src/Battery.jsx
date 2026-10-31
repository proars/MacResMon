import { Card, Stat } from './ui.jsx';
import Ring from './Ring.jsx';

const STATE = { charging: 'Charging', discharging: 'Discharging', charged: 'Charged', 'not charging': 'Not charging', 'finishing charge': 'Finishing charge' };

// Battery and power source. Not shown on Macs without a battery.
export default function Battery({ battery: b }) {
  if (!b) return null;
  const color = b.onBattery && b.percent <= 20 ? 'var(--bad)' : b.onBattery && b.percent <= 40 ? 'var(--warn)' : 'var(--good)';
  return (
    <Card title="Battery" right={b.onBattery ? 'on battery' : 'AC power'}>
      <div className="gauge">
        <Ring value={b.percent / 100} color={color} label={`${b.percent}%`} sub={b.charging ? 'charging' : b.onBattery ? 'battery' : 'plugged in'} />
        <div className="gauge-side">
          <Stat label="Status" value={STATE[b.state] || '–'} />
          <Stat label="Time left" value={b.remaining ? `${b.remaining} h` : '–'} />
          <Stat label="Adapter" value={b.adapterW ? `${b.adapterW} W` : '–'} />
        </div>
      </div>
    </Card>
  );
}
