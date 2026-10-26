/**
 * WYRM DESK REMOTE — core
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
      settings: { is24HourFormat: false, cardFontSize: 13.0, startWeekOnMonday: false },
      display: { brightness: 1.0 },

      tasks: [],
      habits: [],
      calendar: { selectedDate: null, viewMonth: new Date().toISOString(), milestones: [] },
    });
  }

  getState() {
    return this.state;
  }

  mergeSnapshot(data) {
    if (!data) return;
    if (data.layout) Object.assign(this.state.layout, data.layout);
    if (data.settings) Object.assign(this.state.settings, data.settings);
    if (data.display) Object.assign(this.state.display, data.display);
    if (Array.isArray(data.tasks)) this.state.tasks = data.tasks;
    if (Array.isArray(data.habits)) this.state.habits = data.habits;
    if (data.calendar) Object.assign(this.state.calendar, data.calendar);
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
        try { this.socket.close(); } catch (_) {}
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
      state.layout[card] = size;
      post('/api/layout', { card, size }, 'set_layout');
    },
    setAllCardsSize(size) {
      CARDS.forEach((card) => {
        state.layout[card] = size;
        post('/api/layout', { card, size }, 'set_layout');
      });
    },
    toggleNightstand() {
      actions.setCardSize('clock', state.layout.clock === 'nightstand' ? 'fullscreen' : 'nightstand');
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
      if (t) t.isCompleted = !t.isCompleted;
      post('/api/tasks/toggle', { id }, 'toggle_task');
    },
    deleteTask(id) {
      state.tasks = state.tasks.filter((item) => item.id !== id);
      post('/api/tasks/delete', { id }, 'delete_task');
    },
    setFontSize(delta) {
      const current = state.settings.cardFontSize || 13.0;
      const next = Math.min(22.0, Math.max(9.0, current + delta));
      state.settings.cardFontSize = next;
      post('/api/settings', { cardFontSize: next }, 'set_settings');
    },

    /* Habits */
    createHabit({ title, type = 'binary', target = 1, glyph }) {
      const clean = (title || '').trim();
      if (!clean) return false;
      const icon = glyph || draft.glyph;
      post(
        '/api/habits',
        { title: clean, habit_type: type, target: type === 'numeric' ? (target || 1) : 1, glyph: icon, icon_name: icon },
        'create_habit'
      );
      return true;
    },
    isHabitCompletedToday(habit) {
      if (!habit || !habit.completions) return false;
      return (habit.completions[dateKey()] || 0) >= (habit.targetValue || 1);
    },
    getHabitTodayValue(habit) {
      if (!habit || !habit.completions) return 0;
      return habit.completions[dateKey()] || 0;
    },
    habitDayCompleted(habit, key) {
      if (!habit || !habit.completions) return false;
      return (habit.completions[key] || 0) >= (habit.targetValue || 1);
    },
    toggleHabit(id) {
      post('/api/habits/toggle', { id, date: dateKey() }, 'toggle_habit');
    },
    stepHabit(id, delta) {
      post('/api/habits/step', { id, delta, date: dateKey() }, 'step_habit');
    },
    deleteHabit(id) {
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
      if (ms) ms.isPinned = !ms.isPinned;
      post('/api/calendar/milestones/pin', { id }, 'toggle_pin_milestone');
    },
    deleteMilestone(id) {
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
      state.settings.is24HourFormat = is24;
      post('/api/settings', { is24HourFormat: is24 }, 'set_settings');
    },
    setStartWeekOnMonday(startMon) {
      state.settings.startWeekOnMonday = startMon;
      post('/api/settings', { startWeekOnMonday: startMon }, 'set_settings');
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
};
