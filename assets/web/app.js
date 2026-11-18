/**
 * WYRM DESK REMOTE - core
 * State store, WebSocket/REST transport, user actions and app bootstrap.
 * All UI lives in components.js, which must load before this file.
 */

/* --------------------------------------------------------------------------
   REACTIVE STATE STORE
   -------------------------------------------------------------------------- */
class WyrmStateStore {
  constructor() {
    this.state = Vue.reactive({
      currentChannel: 'deck',
      isConnected: false,
      latencyMs: null,

      layout: { clock: 'small', habits: 'small', calendar: 'small', tasks: 'small' },
      settings: { is24HourFormat: false, cardFontSize: 14.0, startWeekOnMonday: false },
      display: { brightness: 1.0 },
      networkModalOpen: false,
      serverUrl: '',
      ipAddress: '',

      tasks: [],
      habits: [],
      calendar: { selectedDate: null, viewMonth: new Date().toISOString(), milestones: [] },
    });

    // Optimistic mutations are tracked per state section so a broadcast that
    // echoes the pre-change value (stale) cannot clobber the newer local
    // change. Entries expire so the server always wins again shortly after.
    this.pending = [];
  }

  /** How long an optimistic mutation stays authoritative without an echo (ms). */
  static get PENDING_TTL_MS() { return 5000; }

  getState() {
    return this.state;
  }

  /**
   * Records a section as optimistically changed, unless one is already
   * pending - the first captured value must stay the pre-change snapshot so
   * repeated actions on the same section keep detecting stale echoes.
   */
  markPendingOnce(key, oldValue) {
    if (this.pending.some((p) => p.key === key)) return;
    this.pending.push({ key, oldValue: JSON.stringify(oldValue), sentAt: Date.now() });
  }

  mergeSnapshot(data) {
    if (!data) return;
    const now = Date.now();
    this.pending = this.pending.filter((p) => now - p.sentAt < WyrmStateStore.PENDING_TTL_MS);

    // Reconcile: a broadcast matching the pre-optimistic value is a stale
    // echo of our own pending change - keep the optimistic value. Any other
    // broadcast (ack echo or a tablet-side change) wins and clears pending.
    const apply = (key, incoming, merge) => {
      if (incoming === undefined) return;
      const index = this.pending.findIndex((p) => p.key === key);
      if (index !== -1) {
        if (JSON.stringify(incoming) === this.pending[index].oldValue) return;
        this.pending.splice(index, 1);
      }
      merge();
    };

    apply('layout', data.layout, () => Object.assign(this.state.layout, data.layout));
    apply('settings', data.settings, () => Object.assign(this.state.settings, data.settings));
    apply('display', data.display, () => Object.assign(this.state.display, data.display));
    apply('networkModalOpen', data.networkModalOpen, () => {
      this.state.networkModalOpen = !!data.networkModalOpen;
    });
    if (data.serverUrl !== undefined) this.state.serverUrl = data.serverUrl;
    if (data.ipAddress !== undefined) this.state.ipAddress = data.ipAddress;
    apply('tasks', data.tasks, () => {
      if (Array.isArray(data.tasks)) this.state.tasks = data.tasks;
    });
    apply('habits', data.habits, () => {
      if (Array.isArray(data.habits)) {
        this.state.habits = data.habits.map((h) => ({
          ...h,
          targetValue: h.targetValue ?? h.target_value ?? 1,
          iconName: h.iconName ?? h.icon_name ?? 'bolt',
        }));
      }
    });
    apply('calendar', data.calendar, () => Object.assign(this.state.calendar, data.calendar));
  }
}

/* --------------------------------------------------------------------------
   WEBSOCKET & REST TRANSPORT
   -------------------------------------------------------------------------- */
class WyrmWebSocketManager {
  constructor(store) {
    this.store = store;
    this.socket = null;
    this.reconnectTimer = null;
    this.heartbeatTimer = null;
    this.lastPingTime = 0;
  }

  connect() {
    if (this.socket && (this.socket.readyState === WebSocket.OPEN || this.socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host || '127.0.0.1:8080';
    const wsUrl = `${protocol}//${host}/ws`;

    try {
      this.socket = new WebSocket(wsUrl);

      this.socket.onopen = () => {
        this.store.state.isConnected = true;
        this._startHeartbeat();
      };

      this.socket.onmessage = (event) => {
        try {
          this._handleMessage(JSON.parse(event.data));
        } catch (e) {
          console.warn('[WyrmWS] Failed to parse message:', e);
        }
      };

      this.socket.onclose = () => {
        this.store.state.isConnected = false;
        this.store.state.latencyMs = null;
        this._stopHeartbeat();
        this._scheduleReconnect();
      };

      this.socket.onerror = () => {
        try { this.socket.close(); } catch (_) { }
      };
    } catch (_) {
      this._scheduleReconnect();
    }
  }

  _scheduleReconnect() {
    if (this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, 2000);
  }

  _startHeartbeat() {
    this._stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.socket && this.socket.readyState === WebSocket.OPEN) {
        this.lastPingTime = Date.now();
        this.send({ type: 'ping', timestamp: this.lastPingTime });
      }
    }, 5000);
  }

  _stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  _handleMessage(msg) {
    if (!msg) return;
    if (msg.type === 'pong' && this.lastPingTime) {
      this.store.state.latencyMs = Math.max(1, Date.now() - this.lastPingTime);
      return;
    }
    if (msg.type === 'snapshot' || msg.type === 'state_update') {
      this.store.mergeSnapshot(msg);
    }
  }

  send(data) {
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify(data));
      return true;
    }
    return false;
  }

  async sendOrPost(endpoint, data, wsType = null) {
    if (wsType && this.send({ type: wsType, ...data })) return true;
    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });
      return res.ok;
    } catch (e) {
      console.warn(`[WyrmNet] Request to ${endpoint} failed:`, e);
      return false;
    }
  }
}

/* --------------------------------------------------------------------------
   ACTIONS
   One object every component receives through inject('wyrm'). It exposes the
   reactive state plus every user action and a few pure helpers, so components
   stay presentational and never talk to the transport directly.
   -------------------------------------------------------------------------- */
function createWyrmActions(store, ws) {
  const state = store.state;
  const CARDS = ['clock', 'habits', 'calendar', 'tasks'];

  // Shared draft: the glyph picked for the next habit (also drives window.wyrmRemote).
  const draft = Vue.reactive({ glyph: '💧' });

  const pad = (n) => String(n).padStart(2, '0');
  // Local calendar date as YYYY-MM-DD. Used everywhere so "today" can never
  // disagree with the week strip (toISOString is UTC and flips at the wrong hour).
  const dateKey = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

  const post = (endpoint, data, type) => ws.sendOrPost(endpoint, data, type);

  // Brightness drags fire constantly; send at most one update per 80ms, always ending on the final value.
  let brightTimer = null;
  let brightPending = null;
  let brightLastSent = 0;

  const actions = {
    state,
    draft,
    dateKey,

    /* Navigation & layout */
    setChannel(name) {
      state.currentChannel = name;
    },
    setCardSize(card, size) {
      store.markPendingOnce('layout', state.layout);
      state.layout[card] = size;
      post('/api/layout', { card, size }, 'set_layout');
    },
    setAllCardsSize(size) {
      CARDS.forEach((card) => actions.setCardSize(card, size));
    },
    toggleNightstand() {
      // Returning from nightstand goes back to the default small deck, not fullscreen.
      actions.setCardSize('clock', state.layout.clock === 'nightstand' ? 'small' : 'nightstand');
    },
    scrollToCard(card) {
      post('/api/scroll', { card }, 'scroll_to_card');
    },

    /* Tasks */
    addTask(title, priority) {
      const clean = (title || '').trim();
      if (!clean) return false;
      post('/api/tasks', { title: clean, priority }, 'create_task');
      return true;
    },
    toggleTask(id) {
      const t = state.tasks.find((item) => item.id === id);
      if (t) {
        store.markPendingOnce('tasks', state.tasks);
        t.is_completed = !t.is_completed;
      }
      post('/api/tasks/toggle', { id }, 'toggle_task');
    },
    deleteTask(id) {
      store.markPendingOnce('tasks', state.tasks);
      state.tasks = state.tasks.filter((item) => item.id !== id);
      post('/api/tasks/delete', { id }, 'delete_task');
    },
    setFontSize(delta) {
      store.markPendingOnce('settings', state.settings);
      const current = state.settings.cardFontSize || 14.0;
      const next = Math.min(22.0, Math.max(11.0, current + delta));
      state.settings.cardFontSize = next;
      post('/api/settings', { cardFontSize: next }, 'set_settings');
    },

    /* Habits */
    createHabit({ title, type = 'binary', target = 1, glyph }) {
      const clean = (title || '').trim();
      if (!clean) return false;
      const icon = glyph || draft.glyph || '💧';
      const count = type === 'numeric' ? (target || 1) : 1;
      post(
        '/api/habits',
        { title: clean, habit_type: type, target: count, target_value: count, targetValue: count, glyph: icon, icon_name: icon },
        'create_habit'
      );
      return true;
    },
    isHabitCompletedToday(habit) {
      if (!habit || !habit.completions) return false;
      const target = habit.targetValue ?? habit.target_value ?? 1;
      return (habit.completions[dateKey()] || 0) >= target;
    },
    getHabitTodayValue(habit) {
      if (!habit || !habit.completions) return 0;
      return habit.completions[dateKey()] || 0;
    },
    habitDayCompleted(habit, key) {
      if (!habit || !habit.completions) return false;
      const target = habit.targetValue ?? habit.target_value ?? 1;
      return (habit.completions[key] || 0) >= target;
    },
    toggleHabit(id) {
      post('/api/habits/toggle', { id, date: dateKey() }, 'toggle_habit');
    },
    stepHabit(id, delta) {
      post('/api/habits/step', { id, delta, date: dateKey() }, 'step_habit');
    },
    deleteHabit(id) {
      store.markPendingOnce('habits', state.habits);
      state.habits = state.habits.filter((h) => h.id !== id);
      post('/api/habits/delete', { id }, 'delete_habit');
    },

    /* Milestones (date is dd/mm/yyyy, as the tablet expects) */
    createMilestone({ title, date, pinned = false }) {
      const cleanTitle = (title || '').trim();
      const cleanDate = (date || '').trim();
      if (!cleanTitle || !cleanDate) return false;
      post('/api/calendar/milestones', { title: cleanTitle, target_date: cleanDate, is_pinned: !!pinned }, 'create_milestone');
      return true;
    },
    togglePinMilestone(id) {
      const ms = state.calendar.milestones.find((m) => m.id === id);
      if (ms) {
        store.markPendingOnce('calendar', state.calendar);
        ms.isPinned = !ms.isPinned;
      }
      post('/api/calendar/milestones/pin', { id }, 'toggle_pin_milestone');
    },
    deleteMilestone(id) {
      store.markPendingOnce('calendar', state.calendar);
      state.calendar.milestones = state.calendar.milestones.filter((m) => m.id !== id);
      post('/api/calendar/milestones/delete', { id }, 'delete_milestone');
    },
    formatMilestoneDate(dateStr) {
      if (!dateStr) return '';
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return dateStr;
      return d.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
    },
    milestoneCountdown(dateStr) {
      if (!dateStr) return '';
      const target = new Date(dateStr);
      if (isNaN(target.getTime())) return '';
      target.setHours(0, 0, 0, 0);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const days = Math.round((target - today) / 86400000);
      if (days === 0) return 'Today';
      if (days === 1) return 'Tomorrow';
      if (days > 1) return `In ${days} days`;
      return days === -1 ? 'Yesterday' : `${Math.abs(days)} days ago`;
    },

    /* Display & settings */
    setBrightness(value) {
      const numVal = typeof value === 'number' ? value : parseFloat(value);
      if (isNaN(numVal)) return;
      store.markPendingOnce('display', state.display);
      state.display.brightness = numVal;
      brightPending = numVal;
      if (brightTimer) return;
      const wait = Math.max(0, 80 - (Date.now() - brightLastSent));
      brightTimer = setTimeout(() => {
        brightTimer = null;
        brightLastSent = Date.now();
        post('/api/display', { brightness: brightPending }, 'set_display');
      }, wait);
    },
    set24HourFormat(is24) {
      store.markPendingOnce('settings', state.settings);
      state.settings.is24HourFormat = is24;
      post('/api/settings', { is24HourFormat: is24 }, 'set_settings');
    },
    setStartWeekOnMonday(startMon) {
      store.markPendingOnce('settings', state.settings);
      state.settings.startWeekOnMonday = startMon;
      post('/api/settings', { startWeekOnMonday: startMon }, 'set_settings');
    },
    toggleNetworkModal(open) {
      const next = typeof open === 'boolean' ? open : !state.networkModalOpen;
      store.markPendingOnce('networkModalOpen', state.networkModalOpen);
      state.networkModalOpen = next;
      post('/api/modal/network', { open: next }, 'toggle_network_modal');
    },
    exportBackup() {
      window.location.href = '/api/backup/export';
    },
    async importBackup(jsonString) {
      const res = await fetch('/api/backup/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: jsonString,
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || 'Import failed with HTTP ' + res.status);
      }
      return await res.json();
    },
  };

  return actions;
}

/* --------------------------------------------------------------------------
   BOOTSTRAP
   -------------------------------------------------------------------------- */
const store = new WyrmStateStore();
const wsManager = new WyrmWebSocketManager(store);
const wyrm = createWyrmActions(store, wsManager);

const app = Vue.createApp(WyrmUI.components.WyrmApp);
WyrmUI.install(app);
app.provide('wyrm', wyrm);
const vm = app.mount('#app');

(async function boot() {
  try {
    const res = await fetch('/api/status');
    if (res.ok) store.mergeSnapshot(await res.json());
  } catch (err) {
    console.warn('[WyrmInit] REST initial sync warning:', err);
  }
  wsManager.connect();
})();

/* --------------------------------------------------------------------------
   PUBLIC WINDOW API (kept for scripts and the tablet bridge)
   -------------------------------------------------------------------------- */
window.wyrmRemote = {
  store,
  wsManager,
  vm,
  setCardSize: (card, size) => wyrm.setCardSize(card, size),
  setAllCardsSize: (size) => wyrm.setAllCardsSize(size),
  scrollToCard: (card) => wyrm.scrollToCard(card),
  toggleStartWeekOnMonday: (val) => wyrm.setStartWeekOnMonday(val),
  toggleNetworkModal: (val) => wyrm.toggleNetworkModal(val),
  createMilestone: (title, date, pinned) => wyrm.createMilestone({ title, date, pinned: !!pinned }),
  deleteMilestone: (id) => wyrm.deleteMilestone(id),
  togglePinMilestone: (id) => wyrm.togglePinMilestone(id),
  createHabit: (title, type, target, glyph) =>
    wyrm.createHabit({ title, type: type || 'binary', target: target || 1, glyph: glyph || '💧' }),
  selectHabitGlyph: (glyph) => { wyrm.draft.glyph = glyph; },
  toggleHabit: (id) => wyrm.toggleHabit(id),
  stepHabit: (id, delta) => wyrm.stepHabit(id, delta),
  deleteHabit: (id) => wyrm.deleteHabit(id),
  setBrightness: (val) => wyrm.setBrightness(val),
  exportBackup: () => wyrm.exportBackup(),
  importBackup: (json) => wyrm.importBackup(json),
};
