import { useState, useEffect, useMemo } from 'react';
import { Card } from './ui.jsx';
import { getState, setState } from './webState.js';
import { RANGES, rangeLabel, fromKey, buildRows, filterSpikes, energy, watts, money, temp, duration, stamp } from './reportModel.js';

const native = () => (typeof window !== 'undefined' ? window.__native : null);

function loadRange() {
  const r = Number(getState('reports.range'));
  return getState('reports.range') != null && RANGES.includes(r) ? r : 30;
}

// Reports page: power use per day with cost, and the log of temperature spikes. The app keeps the data in a file
// (Application Support/MacResMon/reports.json); export and erase run through native dialogs.
// `initial` only seeds the data (for the render check).
export default function Reports({ initial = null }) {
  const [data, setData] = useState(initial);
  const [error, setError] = useState(null);
  const [note, setNote] = useState(null);
  const [range, setRange] = useState(loadRange);

  const load = async () => {
    try {
      const n = native();
      if (!n) throw new Error('Reports are available in the MacResMon app.');
      const text = await n.request('reports.get');
      if (text === 'null') return; // the window is hidden: the app sends nothing
      setData(JSON.parse(text));
      setError(null);
    } catch (e) { setError(e.message || String(e)); }
  };
  useEffect(() => {
    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, []);

  const from = fromKey(range);
  const price = data?.price ?? 0;
  const cur = data?.currency || '$';
  const unit = data?.unit === 'F' ? 'F' : 'C';
  const { rows, total } = useMemo(() => buildRows(data?.days ?? [], from, price), [data, from, price]);
  const spikes = useMemo(() => filterSpikes(data?.spikes ?? [], from), [data, from]);

  const pick = (r) => {
    setRange(r);
    setState('reports.range', r);
  };
  const act = async (type, done) => {
    try {
      const r = await native().request(type, { from: from || '' });
      if (r === 'saved') setNote('CSV saved.');
      else if (r === 'reset') setNote(done);
      else setNote(null);
      await load();
    } catch (e) { setNote(`Failed: ${e.message || e}`); }
  };

  if (!data) return <div className="grid"><Card title="Reports" wide><p className="muted">{error || 'Loading…'}</p></Card></div>;

  const controls = (
    <div className="rp-actions">
      <select className="rp-select" value={range} onChange={(e) => pick(Number(e.target.value))} aria-label="Period">
        {RANGES.map((r) => <option key={r} value={r}>{rangeLabel(r)}</option>)}
      </select>
      <button className="btn" disabled={!rows.length} onClick={() => act('reports.exportDays')}>Export power CSV</button>
      <button className="btn" disabled={!spikes.length} onClick={() => act('reports.exportSpikes')}>Export spikes CSV</button>
      <button className="btn danger" disabled={!data.days.length && !data.spikes.length} onClick={() => act('reports.reset', 'Reports erased. Recording continues from now.')}>Reset</button>
    </div>
  );

  return (
    <div className="grid">
      <Card title="Reports" wide right={controls}>
        <div className="rp-tiles">
          <div className="chip"><small>Energy</small><b>{energy(total.energyJ)}</b></div>
          <div className="chip"><small>Cost</small><b>{money(total.cost, cur)}</b></div>
          <div className="chip"><small>Average / peak power</small><b>{watts(total.avgW)} / {watts(total.peakW || null)}</b></div>
          <div className="chip"><small>Temperature spikes</small><b>{total.spikes}</b></div>
        </div>
        <p className="muted rp-note">
          Price {cur}{price} per kWh (change it in Settings, ⌘,). Energy is the whole-Mac power while MacResMon was running.
          Spikes are CPU or GPU at {temp(90, unit)} or hotter. A day starts at local midnight.{note && <b> {note}</b>}
        </p>
      </Card>

      <Card title="Days" wide right={`${rows.length} ${rows.length === 1 ? 'day' : 'days'}`}>
        <div className="rp-scroll" tabIndex={0}>
          <table className="rp-table">
            <thead><tr><th>Date</th><th className="num">Energy</th><th className="num">Avg</th><th className="num">Peak</th><th className="num">Cost</th><th className="num">Spikes</th><th className="num">Max temp</th></tr></thead>
            <tbody>
              {rows.length > 0 && (
                <tr className="rp-total"><td>Total</td><td className="num">{energy(total.energyJ)}</td><td className="num">{watts(total.avgW)}</td><td className="num">{watts(total.peakW || null)}</td>
                  <td className="num">{money(total.cost, cur)}</td><td className="num">{total.spikes}</td><td className="num">{temp(total.maxTempC, unit)}</td></tr>
              )}
              {rows.map((r) => (
                <tr key={r.day}><td>{r.day}</td><td className="num">{energy(r.energyJ)}</td><td className="num">{watts(r.avgW)}</td><td className="num">{watts(r.peakW || null)}</td>
                  <td className="num">{money(r.cost, cur)}</td><td className="num">{r.spikes || '–'}</td><td className="num">{temp(r.maxTempC, unit)}</td></tr>
              ))}
              {!rows.length && <tr><td colSpan={7} className="muted">Nothing recorded in this period yet.</td></tr>}
            </tbody>
          </table>
        </div>
      </Card>

      <Card title="Temperature spikes" wide right={`${spikes.length} in this period`}>
        <div className="rp-scroll" tabIndex={0}>
          <table className="rp-table">
            <thead><tr><th>Started</th><th>Sensor</th><th className="num">Peak</th><th className="num">Peak reached</th><th className="num" title="Time within 1 °C of the peak">Near peak</th><th className="num">Spike lasted</th></tr></thead>
            <tbody>
              {spikes.map((s) => (
                <tr key={`${s.start}-${s.sensor}`}><td>{stamp(s.start)}</td><td>{s.sensor}</td><td className="num">{temp(s.peakC, unit)}</td>
                  <td className="num">{s.peakAt != null ? stamp(s.peakAt).slice(11) : '–'}</td>
                  <td className="num">{duration((s.peakSecs ?? 0) * 1000)}</td>
                  <td className="num">{duration(s.end - s.start)}{s.ongoing ? ' (now)' : ''}</td></tr>
              ))}
              {!spikes.length && <tr><td colSpan={6} className="muted">No spikes in this period.</td></tr>}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
