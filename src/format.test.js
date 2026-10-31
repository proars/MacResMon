import { test } from 'node:test';
import assert from 'node:assert/strict';
import { gb, pct, num, ghz, temp, mbps, bps, uptime } from './format.js';

test('gb formats byte counts', () => {
  assert.equal(gb(null), '–');
  assert.equal(gb(500 * 1024 ** 2), '0.5 GB');
  assert.equal(gb(12 * 1024 ** 3), '12 GB');
});

test('pct formats percentages', () => {
  assert.equal(pct(null), '–');
  assert.equal(pct(0.1234), '12%');
});

test('num formats numbers', () => {
  assert.equal(num(null), '–');
  assert.equal(num(3.14159, 2, ' GB'), '3.14 GB');
  assert.equal(num(1, 0, ' ms'), '1 ms');
});

test('ghz formats GHz values', () => {
  assert.equal(ghz(null), 'idle');
  assert.equal(ghz(0), 'idle');
  assert.equal(ghz(20000), '20.00 GHz');
});

test('temp converts and formats °C / °F', () => {
  assert.equal(temp(null), '–');
  assert.equal(temp(63.4), '63°C');
  assert.equal(temp(100, 'F'), '212°F');
  assert.equal(temp(0, 'F'), '32°F');
});

test('mbps converts bytes/s to megabits/s', () => {
  assert.equal(mbps(null), '–');
  assert.equal(mbps(0), '0.00 Mbps');
  assert.equal(mbps(125000), '1.00 Mbps');
  assert.equal(mbps(1250000), '10.0 Mbps');
  assert.equal(mbps(25e6), '200 Mbps');
});

test('bps formats bytes per second', () => {
  assert.equal(bps(null), '–');
  assert.equal(bps(500), '500 B/s');
  assert.equal(bps(2048), '2.0 KB/s');
  assert.equal(bps(5 * 1024 ** 2), '5.0 MB/s');
  assert.equal(bps(3 * 1024 ** 3), '3.0 GB/s');
});

test('uptime formats the running time', () => {
  assert.equal(uptime(null), '–');
  assert.equal(uptime(30), '<1m');
  assert.equal(uptime(12 * 60 + 5), '12m');
  assert.equal(uptime(2 * 3600 + 14 * 60), '2h 14m');
  assert.equal(uptime(3 * 86400 + 4 * 3600), '3d 4h');
});
