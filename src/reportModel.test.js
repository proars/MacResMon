import test from 'node:test';
import assert from 'node:assert/strict';
import { buildRows, filterSpikes, fromKey, dayKey, costOf, energy, money, temp, duration } from './reportModel.js';

const days = [
  { day: '2026-01-01', energyJ: 3.6e6, seconds: 3600, peakW: 40, spikes: 1, maxTempC: 92 },
  { day: '2026-01-02', energyJ: 7.2e6, seconds: 7200, peakW: 55, spikes: 0, maxTempC: 70 },
  { day: '2025-12-20', energyJ: 0, seconds: 0, peakW: 0, spikes: 0, maxTempC: null },
];

test('cost is energy in kWh x price', () => {
  assert.equal(costOf(3.6e6, 0.25), 0.25);
  assert.equal(costOf(0, 0.25), 0);
});

test('rows are newest first with totals, average power and cost', () => {
  const { rows, total } = buildRows(days, null, 0.2);
  assert.deepEqual(rows.map((r) => r.day), ['2026-01-02', '2026-01-01', '2025-12-20']);
  assert.equal(rows[2].avgW, null);
  assert.equal(total.energyJ, 10.8e6);
  assert.equal(total.avgW, 10.8e6 / 10800);
  assert.equal(total.peakW, 55);
  assert.equal(total.spikes, 1);
  assert.equal(total.maxTempC, 92);
  assert.ok(Math.abs(total.cost - 0.6) < 1e-9);
});

test('a range keeps only days from its first day; changing the price re-costs', () => {
  const { rows, total } = buildRows(days, '2026-01-02', 1);
  assert.equal(rows.length, 1);
  assert.equal(total.cost, 2);
  assert.equal(buildRows([], null, 1).total.maxTempC, null);
});

test('fromKey: today is day 1; all = null', () => {
  const now = new Date(2026, 2, 1);
  assert.equal(fromKey(7, now), '2026-02-23');
  assert.equal(fromKey(1, now), '2026-03-01');
  assert.equal(fromKey(0, now), null);
  assert.equal(dayKey(new Date(2026, 0, 5)), '2026-01-05');
});

test('spikes are filtered by start day and listed newest first', () => {
  const a = { start: new Date(2026, 0, 1, 12).getTime() }, b = { start: new Date(2026, 0, 3, 12).getTime() };
  assert.deepEqual(filterSpikes([a, b], null), [b, a]);
  assert.deepEqual(filterSpikes([a, b], '2026-01-02'), [b]);
});

test('formatters', () => {
  assert.equal(energy(3600 * 12.34), '12.3 Wh');
  assert.equal(energy(3.6e6 * 1.5), '1.50 kWh');
  assert.equal(energy(null), '–');
  assert.equal(money(0.1234), '$0.123');
  assert.equal(money(12.345, '€'), '€12.35');
  assert.equal(temp(95, 'F'), '203°F');
  assert.equal(temp(95.4), '95°C');
  assert.equal(temp(null), '–');
  assert.equal(duration(45000), '45 s');
  assert.equal(duration(200000), '3 min 20 s');
  assert.equal(duration(3900000), '1 h 05 min');
});
