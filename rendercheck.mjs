// Render smoke test: bundles every component with esbuild and renders it server-side with realistic
// props, including empty states. Run: node rendercheck.mjs (exits 1 on any failure).
import { build } from 'esbuild';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

// Bundles go under node_modules/.cache so that `react` resolves from them; removed on exit.
const tmp = join(process.cwd(), 'node_modules', '.cache', 'rendercheck');
mkdirSync(tmp, { recursive: true });
process.on('exit', () => rmSync(tmp, { recursive: true, force: true }));

async function bundleNamed(entry) { return bundle(entry, true); }
async function bundle(entry, all = false) {
  const out = join(tmp, entry.replace(/\W+/g, '_') + '.mjs');
  await build({
    entryPoints: [entry], bundle: true, platform: 'node', format: 'esm', jsx: 'automatic', outfile: out,
    external: ['react', 'react-dom', 'react-dom/server'], logLevel: 'silent',
  });
  const mod = await import(pathToFileURL(out).href);
  return all ? mod : mod.default;
}

// A realistic snapshot mirroring what the server streams.
const snap = {
  cpu: 0.34, gpu: 0.18, gpuFreq: 742, gpuPower: 1.2, cpuPower: 6.1, chipPower: 8.4, sysPower: 41.5,
  cpuTemp: 63, gpuTemp: 58,
  ramTotal: 68719476736, ramUsed: 32000000000, swapTotal: 1073741824, swapUsed: 512000,
  clusters: [
    { name: 'Performance', freq: 2948, load: 0.42, cores: [] },
    { name: 'Efficiency', freq: 1344, load: 0.11, cores: [] },
  ],
  fans: [{ name: 'fan0', rpm: 2450, max: 7826 }, { name: 'fan1', rpm: 3100, max: 7826 }],
};
const history = Array.from({ length: 20 }, (_, i) => ({
  ts: Date.now() - (20 - i) * 1000, cpu: 0.2 + i * 0.01, power: 30 + i,
  fans: [{ name: 'fan0', rpm: 2000 + i * 20, max: 7826 }, { name: 'fan1', rpm: 2600 + i * 25, max: 7826 }],
}));

let failures = 0;
async function check(name, El, props, expectEmpty = false) {
  try {
    const html = renderToStaticMarkup(createElement(El, props));
    const ok = expectEmpty ? html === '' : html && html.length > 0;
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}  (${html.length} chars)`);
    if (!ok) failures++;
    return html;
  } catch (e) {
    console.log(`FAIL  ${name}  -> ${e.message}`);
    failures++;
    return null;
  }
}

const App = await bundle('src/App.jsx');
const Ring = await bundle('src/Ring.jsx');
const Thermometer = await bundle('src/Thermometer.jsx');
const { Bar, Stat } = await bundleNamed('src/ui.jsx');
const Sparkline = await bundle('src/Sparkline.jsx');
const Fan = await bundle('src/Fan.jsx');
const CoolingCard = await bundle('src/CoolingCard.jsx');
const FanLegend = await bundle('src/FanLegend.jsx');
const Memory = await bundle('src/Memory.jsx');
const Power = await bundle('src/Power.jsx');
const Alerts = await bundle('src/Alerts.jsx');
const Processes = await bundle('src/Processes.jsx');
const Battery = await bundle('src/Battery.jsx');
const PowerBadge = await bundle('src/PowerBadge.jsx');
const MachineButton = await bundle('src/MachineButton.jsx');
const Storage = await bundle('src/Storage.jsx');
const Network = await bundle('src/Network.jsx');
const Reports = await bundle('src/Reports.jsx');
const SettingsButton = await bundle('src/SettingsButton.jsx');

console.log('--- App (connecting, default state) ---');
await check('App', App, {});
console.log('--- components with live data ---');
await check('Ring', Ring, { value: 0.42, color: 'red', label: '42%', sub: 'load' });
await check('Thermometer', Thermometer, { value: 63 });
await check('Thermometer(no data)', Thermometer, { value: null });
await check('Bar', Bar, { value: 0.42 });
await check('Stat', Stat, { label: 'X', value: '41 W' });
await check('Sparkline', Sparkline, { values: [1, 5, 3, 8, 6, 9], max: 10 });
await check('Sparkline(2 lines)', Sparkline, { lines: [{ values: [1, 5, 3], color: 'red' }, { values: [2, 2, 4], color: 'blue' }] });
await check('Sparkline(empty)', Sparkline, { values: [] });
await check('Fan', Fan, { label: 'Fan 1', rpm: 2450, max: 7826 });
await check('Fan(0rpm)', Fan, { label: 'Fan 1', rpm: 0, max: 7826 });
await check('CoolingCard', CoolingCard, { fans: snap.fans, history });
await check('CoolingCard(no fans)', CoolingCard, { fans: [], history: [] });
await check('FanLegend', FanLegend, { fans: snap.fans });
await check('FanLegend(empty)', FanLegend, { fans: [] }, true);
await check('Memory', Memory, { snap, history });
await check('Power', Power, { snap, history });

const procs = { cpu: [{ pid: 1, name: 'WindowServer', cpu: 39.1, rss: 311280 * 1024 }], mem: [{ pid: 2, name: 'Brave', cpu: 1, rss: 2297344 * 1024 }] };
await check('Alerts', Alerts, { alerts: [{ id: 'mem', level: 'warning', text: 'Memory is 91% full' }] });
await check('Alerts(none)', Alerts, { alerts: [] }, true);
await check('Processes', Processes, { procs });
await check('Processes(waiting)', Processes, { procs: null });
await check('Battery', Battery, { battery: { percent: 80, onBattery: false, charging: false, state: 'not charging', remaining: null, adapterW: 65 } });
await check('Battery(none)', Battery, { battery: null }, true);
await check('Storage', Storage, { disk: { total: 2e12, free: 1.2e12 }, io: { read: 1e6, write: 5e5 }, history });
await check('Storage(no data)', Storage, { disk: null, io: null, history: [] });
await check('Network', Network, { net: { in: 2e6, out: 1e5 }, history });
await check('Network(no data)', Network, { net: null, history: [] });
const ac = { percent: 80, onBattery: false, charging: false, state: 'not charging', remaining: null, adapterW: 65, batteryW: 0 };
await check('PowerBadge(AC)', PowerBadge, { battery: ac });
await check('PowerBadge(charging)', PowerBadge, { battery: { ...ac, charging: true, batteryW: 12.3 } });
await check('PowerBadge(adapter too weak)', PowerBadge, { battery: { ...ac, batteryW: -4.2 } });
await check('PowerBadge(on battery)', PowerBadge, { battery: { ...ac, onBattery: true, adapterW: null, batteryW: -12.3, remaining: '3:41', percent: 15 } });
await check('PowerBadge(none)', PowerBadge, { battery: null }, true);
const machine = { name: 'MacBook Pro', model: 'Mac17,7', chip: 'Apple M5 Pro', os: '26.1', memory: '64 GB', cores: 18, gpuCores: 20, tiers: [{ name: 'Super', cores: 6 }, { name: 'Performance', cores: 12 }] };
await check('MachineButton', MachineButton, { m: machine, ram: { used: 41e9, total: 64e9 }, disk: { total: 2e12, free: 1.2e12 } });
await check('MachineButton(open)', MachineButton, { m: machine, ram: { used: 41e9, total: 64e9 }, disk: { total: 2e12, free: 1.2e12 }, initialOpen: true });
await check('MachineButton(open, no ram or disk)', MachineButton, { m: { ...machine, tiers: undefined }, ram: { used: undefined, total: undefined }, disk: null, initialOpen: true });
await check('MachineButton(unknown)', MachineButton, { m: null }, true);
await check('Thermometer(F)', Thermometer, { value: 63, unit: 'F' });

const day = (d, over = {}) => ({ day: d, energyJ: 5.4e5, seconds: 3600, peakW: 38, spikes: 0, maxTempC: 71, ...over });
const reportData = {
  price: 0.17, currency: '$', unit: 'C',
  days: [day('2026-01-01', { spikes: 1, maxTempC: 94 }), day(new Date().toISOString().slice(0, 10)), day('2026-01-03', { maxTempC: null, seconds: 0, energyJ: 0 })],
  spikes: [{ start: Date.now() - 6e4, end: Date.now(), sensor: 'CPU', peakC: 94.2, ongoing: true, peakAt: Date.now() - 3e4, peakSecs: 20 }, { start: Date.now() - 9e6, end: Date.now() - 8.9e6, sensor: 'GPU', peakC: 91, ongoing: false }],
};
await check('SettingsButton', SettingsButton, {});
await check('Reports', Reports, { initial: reportData });
await check('Reports(F)', Reports, { initial: { ...reportData, unit: 'F' } });
await check('Reports(empty log)', Reports, { initial: { ...reportData, days: [], spikes: [] } });
await check('Reports(loading)', Reports, {});

console.log(failures === 0 ? '\nALL RENDER CHECKS PASSED' : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
