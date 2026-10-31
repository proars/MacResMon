// One color per fan line; shared by the graph and its legend.
const FAN_COLORS = ['var(--accent)', 'var(--accent2)', 'var(--accent3)', 'var(--good)'];
export const fanColor = (i) => FAN_COLORS[i % FAN_COLORS.length];
