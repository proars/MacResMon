import { Component } from 'react';

// Catches render errors anywhere in the tree so a single broken card can't blank
// the whole dashboard (the original failure mode).
export class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  componentDidCatch(error, info) {
    console.error('Dashboard error boundary caught:', error, info);
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 24, maxWidth: 520, margin: '40px auto', color: '#ef4444' }}>
          <h1 style={{ margin: '0 0 8px' }}>Something went wrong</h1>
          <p style={{ color: 'var(--muted)' }}>{String(this.state.error?.message || this.state.error)}</p>
          <button
            onClick={() => this.setState({ error: null })}
            style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--line)', background: 'var(--card)', cursor: 'pointer' }}
          >
            Retry
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
