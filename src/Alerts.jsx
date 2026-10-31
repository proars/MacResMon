// Active alerts as compact chips in the header (overheating, fan at max, memory, battery, disk).
// The row never wraps, so an alert appearing or clearing does not move anything on the page.
const SHOWN = 2;

export default function Alerts({ alerts = [] }) {
  if (!alerts.length) return null;
  const sorted = [...alerts].sort((a, b) => (a.level === 'critical' ? 0 : 1) - (b.level === 'critical' ? 0 : 1));
  const more = sorted.slice(SHOWN);
  return (
    <div className="alerts" role="alert">
      {sorted.slice(0, SHOWN).map((a) => (
        <span key={a.id} className={`badge alert ${a.level}`} title={a.text}>{a.text}</span>
      ))}
      {more.length > 0 && (
        <span className={`badge alert more ${more.some((a) => a.level === 'critical') ? 'critical' : 'warning'}`} title={more.map((a) => a.text).join('\n')}>+{more.length}</span>
      )}
    </div>
  );
}
