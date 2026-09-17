/**
 * Wyrm Desk — Simplified Remote Companion Engine
 * Architecture: ES6 Reactive Store, WebSocket & REST Transport, Streamlined DOM View Controller
 */

/**
 * Manages local reactive state and notifies registered listeners upon mutations.
 */
class WyrmStateStore {
  constructor() {
    this.state = {
      layout: {
        clock: 'small',
        habits: 'small',
        calendar: 'small',
        tasks: 'small',
      },
      settings: {
        is24HourFormat: false,
      },
      activeFilter: 'all',
      isConnected: false,
    };
    this.listeners = new Set();
  }

  subscribe(listener) {
    this.listeners.add(listener);
    listener(this.state);
    return () => this.listeners.delete(listener);
  }

  setState(partialState) {
    this.state = {
      ...this.state,
      ...partialState,
      layout: { ...this.state.layout, ...(partialState.layout || {}) },
      settings: { ...this.state.settings, ...(partialState.settings || {}) },
    };
    for (const listener of this.listeners) {
      listener(this.state);
    }
  }

  getState() {
    return this.state;
  }
}

/**
 * Handles persistent WebSocket communication with the tablet Shelf server.
 */
class WyrmWebSocketManager {
  constructor(store) {
    this.store = store;
    this.socket = null;
    this.reconnectTimer = null;
  }

  connect() {
    if (this.socket && (this.socket.readyState === WebSocket.OPEN || this.socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const isSecure = window.location.protocol === 'https:';
    const protocol = isSecure ? 'wss:' : 'ws:';
    const endpoint = `${protocol}//${window.location.host}/ws`;

    try {
      this.socket = new WebSocket(endpoint);

      this.socket.onopen = () => {
        this.store.setState({ isConnected: true });
        if (this.reconnectTimer) {
          clearInterval(this.reconnectTimer);
          this.reconnectTimer = null;
        }
      };

      this.socket.onmessage = (event) => {
        this._handleIncomingMessage(event.data);
      };

      this.socket.onclose = () => {
        this.store.setState({ isConnected: false });
        this._scheduleReconnect();
      };

      this.socket.onerror = () => {
        if (this.socket) {
          this.socket.close();
        }
      };
    } catch (_) {
      this._scheduleReconnect();
    }
  }

  sendLayoutMutation(card, size) {
    const message = JSON.stringify({ type: 'set_layout', card, size });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/layout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ card, size }),
      }).catch(() => {});
    }
  }

  sendSettingsMutation(settingsPayload) {
    const message = JSON.stringify({
      type: 'set_settings',
      ...settingsPayload,
    });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settingsPayload),
      }).catch(() => {});
    }
  }

  _handleIncomingMessage(rawMessage) {
    try {
      const payload = JSON.parse(rawMessage);
      if (payload.type === 'snapshot' || payload.type === 'state_update') {
        this.store.setState({
          layout: payload.layout || {},
          settings: payload.settings || {},
        });
      }
    } catch (_) {}
  }

  _scheduleReconnect() {
    if (!this.reconnectTimer) {
      this.reconnectTimer = setInterval(() => this.connect(), 2000);
    }
  }
}

/**
 * Updates DOM tree elements and interactive controls to reflect state changes.
 */
class WyrmUiRenderer {
  constructor(store, wsManager) {
    this.store = store;
    this.wsManager = wsManager;
    this._cacheDomElements();
  }

  _cacheDomElements() {
    this.networkBadge = document.getElementById('networkBadge');
    this.networkLabel = document.getElementById('networkLabel');
    this.timeFormatToggle = document.getElementById('timeFormatToggle');
    this.cardClock = document.getElementById('card-clock');

    this.cardMap = {
      clock: document.getElementById('card-clock'),
      habits: document.getElementById('card-habits'),
      calendar: document.getElementById('card-calendar'),
      tasks: document.getElementById('card-tasks'),
    };

    this.tabButtons = {
      all: document.getElementById('tab-all'),
      clock: document.getElementById('tab-clock'),
      habits: document.getElementById('tab-habits'),
      calendar: document.getElementById('tab-calendar'),
      tasks: document.getElementById('tab-tasks'),
    };
  }

  setCardFilter(filterName) {
    this.store.setState({ activeFilter: filterName });
  }

  setCardSize(card, size) {
    this.store.setState({ layout: { [card]: size } });
    this.wsManager.sendLayoutMutation(card, size);
  }

  toggleTimeFormat() {
    const is24Hour = !this.store.getState().settings.is24HourFormat;
    this.store.setState({ settings: { is24HourFormat: is24Hour } });
    this.wsManager.sendSettingsMutation({ is24HourFormat: is24Hour });
  }

  render(state) {
    this._renderNetworkStatus(state);
    this._renderPageSwitcher(state);
    this._renderCards(state);
    this._render24HourToggle(state);
  }

  _renderNetworkStatus(state) {
    if (!this.networkBadge || !this.networkLabel) return;

    if (state.isConnected) {
      this.networkBadge.classList.add('connected');
      this.networkLabel.textContent = 'LIVE';
    } else {
      this.networkBadge.classList.remove('connected');
      this.networkLabel.textContent = 'CONNECTING...';
    }
  }

  _renderPageSwitcher(state) {
    const activeFilter = state.activeFilter || 'all';

    // Update capsule tabs
    Object.keys(this.tabButtons).forEach((key) => {
      const btn = this.tabButtons[key];
      if (btn) {
        btn.classList.toggle('active', key === activeFilter);
      }
    });

    // Update card stream visibility
    Object.keys(this.cardMap).forEach((cardKey) => {
      const cardEl = this.cardMap[cardKey];
      if (cardEl) {
        if (activeFilter === 'all' || activeFilter === cardKey) {
          cardEl.classList.remove('filtered-out');
        } else {
          cardEl.classList.add('filtered-out');
        }
      }
    });
  }

  _renderCards(state) {
    const cardTypes = ['clock', 'habits', 'calendar', 'tasks'];

    for (const card of cardTypes) {
      const activeSize = state.layout[card] || 'small';

      // Update status capsule
      const statusBadge = document.getElementById(`${card}StatusBadge`);
      if (statusBadge) {
        statusBadge.textContent = activeSize.toUpperCase();
        if (activeSize === 'nightstand') {
          statusBadge.className = 'status-capsule amber';
        } else {
          statusBadge.className = 'status-capsule';
        }
      }

      // Update segmented size buttons
      const sizeList = card === 'clock'
        ? ['small', 'medium', 'fullscreen', 'nightstand']
        : ['small', 'medium', 'fullscreen'];

      for (const size of sizeList) {
        const btn = document.getElementById(`${card}-${size}`);
        if (btn) {
          btn.classList.remove('active', 'active-amber');
          if (size === activeSize) {
            btn.classList.add(size === 'nightstand' ? 'active-amber' : 'active');
          }
        }
      }
    }

    // Update Nightstand styling on clock card
    if (this.cardClock) {
      this.cardClock.classList.toggle('nightstand-active', state.layout.clock === 'nightstand');
    }
  }

  _render24HourToggle(state) {
    if (!this.timeFormatToggle) return;
    const is24Hour = state.settings.is24HourFormat;

    this.timeFormatToggle.classList.toggle('active', is24Hour);
    this.timeFormatToggle.setAttribute('aria-checked', is24Hour ? 'true' : 'false');
  }
}

// Application Bootstrap Execution
document.addEventListener('DOMContentLoaded', async () => {
  const store = new WyrmStateStore();
  const wsManager = new WyrmWebSocketManager(store);
  const renderer = new WyrmUiRenderer(store, wsManager);

  // Global interface for inline triggers
  window.wyrmRemote = {
    setCardSize: (card, size) => renderer.setCardSize(card, size),
    toggleTimeFormat: () => renderer.toggleTimeFormat(),
    setCardFilter: (filter) => renderer.setCardFilter(filter),
  };

  // Subscribe renderer to state mutations
  store.subscribe((state) => renderer.render(state));

  // Perform initial REST synchronization
  try {
    const response = await fetch('/api/status', { cache: 'no-store' });
    if (response.ok) {
      const initialSnapshot = await response.json();
      store.setState({
        layout: initialSnapshot.layout || {},
        settings: initialSnapshot.settings || {},
      });
    }
  } catch (_) {}

  // Connect live WebSocket channel
  wsManager.connect();
});
