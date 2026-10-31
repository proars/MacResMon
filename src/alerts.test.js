import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateAlerts } from './alerts.js';

const ids = (s, u) => evaluateAlerts(s, u).map((a) => a.id);

test('no alerts for a calm system and for an empty snapshot', () => {
  assert.deepEqual(evaluateAlerts({ cpuTemp: 60, gpuTemp: 55, ramTotal: 100, ramUsed: 50, fans: [{ rpm: 2000, max: 7000 }] }), []);
  assert.deepEqual(evaluateAlerts({}), []);
  assert.deepEqual(evaluateAlerts(undefined), []);
});

test('temperature alerts start at 90 °C and turn critical at 100 °C', () => {
  assert.deepEqual(ids({ cpuTemp: 89.9, gpuTemp: 90 }), ['gpu-temp']);
  assert.equal(evaluateAlerts({ cpuTemp: 100 })[0].level, 'critical');
  assert.equal(evaluateAlerts({ cpuTemp: 92 })[0].level, 'warning');
});

test('alert text follows the temperature unit', () => {
  assert.match(evaluateAlerts({ cpuTemp: 95 }, 'F')[0].text, /203°F/);
  assert.match(evaluateAlerts({ cpuTemp: 95 }, 'C')[0].text, /95°C/);
});

test('fan at >= 95% of its max alerts; max of 0 is ignored', () => {
  assert.deepEqual(ids({ fans: [{ rpm: 6700, max: 7000 }, { rpm: 100, max: 7000 }, { rpm: 9999, max: 0 }] }), ['fan-0']);
});

test('memory alert at 90%, critical at 95%', () => {
  assert.deepEqual(ids({ ramTotal: 100, ramUsed: 90 }), ['mem']);
  assert.equal(evaluateAlerts({ ramTotal: 100, ramUsed: 96 })[0].level, 'critical');
  assert.deepEqual(ids({ ramTotal: 0, ramUsed: 5 }), []);
});

test('battery alert only while on battery; disk alert when <= 10% free', () => {
  assert.deepEqual(ids({ battery: { onBattery: true, percent: 8 } }), ['battery']);
  assert.deepEqual(ids({ battery: { onBattery: false, percent: 3 } }), []);
  assert.deepEqual(ids({ disk: { total: 100, free: 9 } }), ['disk']);
  assert.deepEqual(ids({ disk: { total: 100, free: 50 } }), []);
});
