import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { heat } from './ui.jsx';
import { gb, pct } from './format.js';

// A plain tile; with `fill` (0..1) the tile itself is filled from the left, in `color`, to show how full something is.
function Chip({ label, value, fill, color }) {
  return (
    <div className={'chip' + (fill != null ? ' filled' : '')} style={fill != null ? { '--c': color, '--f': `${Math.min(100, Math.max(fill > 0 ? 3 : 0, fill * 100))}%` } : undefined} title={fill != null ? pct(fill) + ' full' : undefined}>
      <small>{label}</small><b>{value}</b>
    </div>
  );
}

// "This Mac" button in the header: chip, macOS, core counts, memory and disk in a popover, closed by a click outside or Esc.
// `m` is the machine facts from the snapshot, `ram` = { used, total } in bytes, `disk` = { total, free }.
export default function MachineButton({ m, ram, disk, initialOpen = false }) {
  const [open, setOpen] = useState(initialOpen);
  const [leaving, setLeaving] = useState(false); // plays the closing animation before the popover is removed
  const box = useRef(null);
  const close = () => { setLeaving(true); setTimeout(() => { setOpen(false); setLeaving(false); }, 140); };
  useEffect(() => {
    if (!open) return undefined;
    const away = (e) => { if (!box.current?.contains(e.target)) close(); };
    const esc = (e) => { if (e.key === 'Escape') close(); };
    document.addEventListener('pointerdown', away);
    document.addEventListener('keydown', esc);
    return () => { document.removeEventListener('pointerdown', away); document.removeEventListener('keydown', esc); };
  }, [open]);
  if (!m) return null;
  const tiers = Array.isArray(m.tiers) ? m.tiers : [];
  const used = ram?.total > 0 ? ram.used / ram.total : null;
  const diskUsed = disk?.total > 0 ? 1 - disk.free / disk.total : null;
  // The scrim is a portal: the header's backdrop-filter would otherwise confine a fixed element to the header.
  const scrim = open && typeof document !== 'undefined' ? createPortal(<div className={'mp-scrim' + (leaving ? ' out' : '')} />, document.body) : null;
  return (
    <div className="mp" ref={box}>
      {scrim}
      <button className={'icon-btn' + (open && !leaving ? ' on' : '')} onClick={() => (open && !leaving ? close() : leaving ? null : setOpen(true))} aria-label="This Mac" aria-expanded={open && !leaving} aria-haspopup="dialog" title="This Mac">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><rect x="5" y="5" width="14" height="14" rx="2" /><rect x="9" y="9" width="6" height="6" rx="1" /><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3" /></svg>
      </button>
      {open && (
        <div className={'mp-pop' + (leaving ? ' out' : '')} role="dialog" aria-label="This Mac" title={[m.name, m.model && `(${m.model})`].filter(Boolean).join(' ') || undefined}>
          <div className="mp-name"><b>{m.chip || m.name || 'This Mac'}</b>{m.os && <span className="muted">macOS {m.os}</span>}</div>
          <div className="chips">
            <Chip label="CPU cores" value={m.cores ?? '–'} />
            {tiers.map((t) => <Chip key={t.name} label={`${t.name} cores`} value={t.cores} />)}
            <Chip label="GPU cores" value={m.gpuCores ?? '–'} />
            {used != null ? <Chip label="Memory used" value={`${gb(ram.used)} / ${gb(ram.total)}`} fill={used} color={heat(used)} /> : <Chip label="Memory" value={m.memory ?? '–'} />}
            {diskUsed != null && <Chip label="Disk used" value={`${gb(disk.total - disk.free)} / ${gb(disk.total)}`} fill={diskUsed} color={heat(diskUsed)} />}
          </div>
        </div>
      )}
    </div>
  );
}
