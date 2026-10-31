import { Card } from './ui.jsx';
import { gb, num } from './format.js';

function List({ title, rows, cell }) {
  return (
    <div>
      <h3>{title}</h3>
      <table className="procs">
        <tbody>
          {rows.map((p) => (
            <tr key={p.pid}><td className="cmd" title={`${p.name} (pid ${p.pid})`}>{p.name}</td><td className="num">{cell(p)}</td></tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// Which processes are using the machine: top 5 by CPU and top 5 by memory.
export default function Processes({ procs }) {
  const cpu = procs?.cpu ?? [], mem = procs?.mem ?? [];
  return (
    <Card title="Top processes" right="what is heating the Mac" wide>
      {!cpu.length ? <p className="muted">Waiting for process data…</p> : (
        <div className="split">
          <List title="By CPU" rows={cpu} cell={(p) => `${num(p.cpu, 1)}%`} />
          <List title="By memory" rows={mem} cell={(p) => gb(p.rss)} />
        </div>
      )}
    </Card>
  );
}
