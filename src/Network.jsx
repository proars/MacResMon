import { Card } from './ui.jsx';
import Sparkline from './Sparkline.jsx';
import { bps, mbps } from './format.js';

// Network throughput over all non-loopback interfaces: download and upload.
export default function Network({ net, history = [] }) {
  const lines = [
    { values: history.map((h) => h.netIn), color: 'var(--good)' },
    { values: history.map((h) => h.netOut), color: 'var(--accent3)' },
  ];
  return (
    <Card title="Network" right="all interfaces">
      <div className="net">
        <div><small className="muted">Download</small><div className="big">{bps(net?.in)}</div><div className="muted">{mbps(net?.in)}</div></div>
        <div><small className="muted">Upload</small><div className="big">{bps(net?.out)}</div><div className="muted">{mbps(net?.out)}</div></div>
      </div>
      <Sparkline lines={lines} height={48} />
      <div className="legend">
        <span className="legend-item"><i className="swatch" style={{ background: 'var(--good)' }} />download</span>
        <span className="legend-item"><i className="swatch" style={{ background: 'var(--accent3)' }} />upload</span>
      </div>
    </Card>
  );
}
