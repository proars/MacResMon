// Header badge for the power source: a battery glyph (fill = charge, bolt while on mains) and, on mains, a plug.
// "AC power 80%" / "Battery 55% · draining 12.3 W · 3:41 left". The details are in the tooltip.
export default function PowerBadge({ battery: b }) {
  if (!b) return null;
  const watts = b.batteryW ?? 0;
  const low = b.onBattery && b.percent <= 20;
  // On mains but still losing charge: the adapter is too weak. The plug blinks and the explanation is only in the tooltip.
  const weak = !b.onBattery && watts < -0.5;
  const adapter = b.adapterW && !b.onBattery ? `. Adapter: ${b.adapterW} W` : '';
  const title = weak ? `AC power ${b.percent}% · adapter too weak, battery draining ${(-watts).toFixed(1)} W${adapter}`
    : (b.onBattery ? 'Running on battery' : b.charging ? 'Plugged in, charging' : 'Plugged in, not charging') + adapter;
  return (
    <span className={'badge' + (low ? ' down' : b.onBattery ? ' busy' : '')} title={title}>
      <svg className="pw-ico" viewBox="0 0 28 14" width="26" height="13" aria-hidden="true">
        <rect x="0.75" y="0.75" width="23" height="12.5" rx="3" fill="none" stroke="currentColor" strokeWidth="1.5" />
        <rect x="25" y="4.5" width="2.5" height="5" rx="1" fill="currentColor" />
        <rect x="2.5" y="2.5" width={Math.max(1, (19.5 * b.percent) / 100)} height="9" rx="1.6" fill="currentColor" />
        {!b.onBattery && <path d="M13.5 2l-4 6h3l-1 4 4.5-6h-3z" fill="var(--card)" stroke="var(--card)" strokeWidth=".6" strokeLinejoin="round" />}
      </svg>
      {!b.onBattery && (
        <svg className={'pw-ico' + (weak ? ' pw-weak' : '')} viewBox="0 0 16 16" width="13" height="13" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M5.5 1.5v3.5M10.5 1.5v3.5M3.5 5h9v2.5a4.5 4.5 0 0 1-9 0zM8 12v2.5" />
        </svg>
      )}
      {b.onBattery ? 'Battery' : 'AC power'} {b.percent}%
      {watts > 0.5 && ` · charging ${watts.toFixed(1)} W`}
      {watts < -0.5 && b.onBattery && ` · draining ${(-watts).toFixed(1)} W`}
      {b.onBattery && b.remaining && ` · ${b.remaining} left`}
    </span>
  );
}
