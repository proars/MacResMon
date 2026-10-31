import { Card, Bar, Stat, heat } from './ui.jsx';
import Sparkline from './Sparkline.jsx';
import { gb, pct, bps } from './format.js';

// Disk usage plus live read/write throughput.
export default function Storage({ disk, io, history = [] }) {
  const used = disk ? 1 - disk.free / disk.total : 0;
  const lines = [
    { values: history.map((h) => h.diskR), color: 'var(--accent)' },
    { values: history.map((h) => h.diskW), color: 'var(--accent2)' },
  ];
  return (
    <Card title="Storage" right={disk ? `${gb(disk.total)} total` : undefined}>
      {disk ? (
        <>
          <div className="row"><b>{gb(disk.free)} free</b><span className="muted">{pct(used)} used</span></div>
          <Bar value={used} color={heat(used)} />
        </>
      ) : <p className="muted">No disk data.</p>}
      <Stat label="Read" value={bps(io?.read)} />
      <Stat label="Write" value={bps(io?.write)} />
      <Sparkline lines={lines} height={48} />
      <div className="legend">
        <span className="legend-item"><i className="swatch" style={{ background: 'var(--accent)' }} />read</span>
        <span className="legend-item"><i className="swatch" style={{ background: 'var(--accent2)' }} />write</span>
      </div>
    </Card>
  );
}
