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
        cardFontSize: 14.0,
      },
      tasks: [],
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
      tasks: partialState.tasks !== undefined ? partialState.tasks : this.state.tasks,
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

  createTask(title, priority = 'normal') {
    const message = JSON.stringify({ type: 'create_task', title, priority });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, priority }),
      }).catch(() => {});
    }
  }

  toggleTask(id) {
    const message = JSON.stringify({ type: 'toggle_task', id });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/tasks/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      }).catch(() => {});
    }
  }

  deleteTask(id) {
    const message = JSON.stringify({ type: 'delete_task', id });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/tasks/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
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
          tasks: payload.tasks !== undefined ? payload.tasks : this.store.getState().tasks,
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
    this.fontSizeDisplay = document.getElementById('fontSizeDisplay');
    this.cardClock = document.getElementById('card-clock');
    this.tasksList = document.getElementById('tasksList');
    this.tasksCounter = document.getElementById('tasksCounter');
    this.taskInput = document.getElementById('taskInput');
    this.taskPriority = document.getElementById('taskPriority');

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

  incrementFontSize() {
    const current = (this.store.getState().settings && this.store.getState().settings.cardFontSize) || 14.0;
    const updated = Math.min(22.0, Math.round(current + 1.0));
    this.store.setState({ settings: { cardFontSize: updated } });
    this.wsManager.sendSettingsMutation({ cardFontSize: updated });
  }

  decrementFontSize() {
    const current = (this.store.getState().settings && this.store.getState().settings.cardFontSize) || 14.0;
    const updated = Math.max(11.0, Math.round(current - 1.0));
    this.store.setState({ settings: { cardFontSize: updated } });
    this.wsManager.sendSettingsMutation({ cardFontSize: updated });
  }

  addTask() {
    if (!this.taskInput) return;
    const title = this.taskInput.value.trim();
    if (!title) return;
    const priority = this.taskPriority ? this.taskPriority.value : 'normal';
    this.wsManager.createTask(title, priority);
    this.taskInput.value = '';
  }

  toggleTask(id) {
    this.wsManager.toggleTask(id);
  }

  deleteTask(id) {
    this.wsManager.deleteTask(id);
  }

  render(state) {
    this._renderNetworkStatus(state);
    this._renderPageSwitcher(state);
    this._renderCards(state);
    this._render24HourToggle(state);
    this._renderFontSize(state);
    this._renderTasks(state);
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

    // Synchronize page data attribute on body for scoped CSS rules
    document.body.setAttribute('data-active-page', activeFilter);

    // Update capsule tabs
    Object.keys(this.tabButtons).forEach((key) => {
      const btn = this.tabButtons[key];
      if (btn) {
        btn.classList.toggle('active', key === activeFilter);
      }
    });

    // Update card stream visibility across all cards
    const allCards = document.querySelectorAll('.layout-card');
    allCards.forEach((cardEl) => {
      const cardCategory = cardEl.getAttribute('data-card');
      const isDetailCard = cardEl.classList.contains('detail-card');

      if (activeFilter === 'all') {
        if (isDetailCard) {
          cardEl.classList.add('filtered-out');
        } else {
          cardEl.classList.remove('filtered-out');
        }
      } else {
        if (cardCategory === activeFilter) {
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

  _renderFontSize(state) {
    if (!this.fontSizeDisplay) return;
    const fontSize = (state.settings && state.settings.cardFontSize) || 14.0;
    this.fontSizeDisplay.textContent = `${Math.round(fontSize)} pt`;
  }

  _renderTasks(state) {
    if (!this.tasksList) return;

    const tasks = state.tasks || [];
    const completedCount = tasks.filter((t) => t.is_completed || t.completed).length;

    if (this.tasksCounter) {
      this.tasksCounter.textContent = `${completedCount}/${tasks.length}`;
    }

    if (tasks.length === 0) {
      this.tasksList.innerHTML = '<div class="tasks-empty-msg">No tasks yet. Add one above!</div>';
      return;
    }

    const cardFontSize = Math.round((state.settings && state.settings.cardFontSize) || 14);

    this.tasksList.innerHTML = tasks.map((task) => {
      const isCompleted = !!(task.is_completed || task.completed);
      const isHigh = (task.priority || '').toLowerCase() === 'high';
      const checkIcon = isCompleted
        ? '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>'
        : '';
      const priorityBadge = (isHigh && !isCompleted)
        ? '<span class="task-priority-tag">HIGH</span>'
        : '';

      return `
        <div class="task-item-row ${isCompleted ? 'completed' : ''}" data-task-id="${task.id}">
          <button class="task-checkbox ${isCompleted ? 'checked' : ''}" onclick="window.wyrmRemote.toggleTask('${task.id}')" title="Toggle completion">
            ${checkIcon}
          </button>
          <span class="task-title-text" style="font-size: ${cardFontSize}px" onclick="window.wyrmRemote.toggleTask('${task.id}')">${this._escapeHtml(task.title || task.text || '')}</span>
          ${priorityBadge}
          <button class="task-delete-btn" onclick="window.wyrmRemote.deleteTask('${task.id}')" title="Delete task">×</button>
        </div>
      `;
    }).join('');
  }

  _escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
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
    incrementFontSize: () => renderer.incrementFontSize(),
    decrementFontSize: () => renderer.decrementFontSize(),
    setCardFilter: (filter) => renderer.setCardFilter(filter),
    addTask: () => renderer.addTask(),
    toggleTask: (id) => renderer.toggleTask(id),
    deleteTask: (id) => renderer.deleteTask(id),
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
        tasks: initialSnapshot.tasks || [],
      });
    }
  } catch (_) {}

  // Connect live WebSocket channel
  wsManager.connect();
});
