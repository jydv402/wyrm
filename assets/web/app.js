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

      layout: {
        clock: 'small',
        habits: 'small',
        calendar: 'small',
        tasks: 'small',
        reminder: 'small',
        sharing: 'small',
      },
      settings: { is24HourFormat: false, cardFontSize: 14.0, startWeekOnMonday: false },
      display: { brightness: 1.0 },
      networkModalOpen: false,
      serverUrl: '',
      ipAddress: '',

      tasks: [],
      habits: [],
      reminders: [],
      activeAlarm: null,
      calendar: { selectedDate: null, viewMonth: new Date().toISOString(), milestones: [] },
      sharing: {
        hasPermission: false,
        rootPath: '',
        revision: 0,
        token: (() => {
          try { return sessionStorage.getItem('wyrm_sharing_token') || ''; } catch (_) { return ''; }
        })(),
        currentPath: '',
        entries: [],
        totalBytes: 0,
        sortBy: 'name',
        sortAscending: true,
        searchQuery: '',
        isLoading: false,
        error: '',
        uploads: [],
      },
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
    apply('reminders', data.reminders, () => {
      if (Array.isArray(data.reminders)) {
        this.state.reminders = data.reminders;
      }
    });
    const incomingAlarm = data.active_alarm !== undefined ? data.active_alarm : data.activeAlarm;
    apply('activeAlarm', incomingAlarm, () => {
      this.state.activeAlarm = incomingAlarm || null;
    });
    apply('calendar', data.calendar, () => Object.assign(this.state.calendar, data.calendar));
    if (data.sharing && typeof data.sharing === 'object') {
      if (data.sharing.has_permission !== undefined) {
        this.state.sharing.hasPermission = !!data.sharing.has_permission;
      }
      if (data.sharing.root_path !== undefined) {
        this.state.sharing.rootPath = data.sharing.root_path || '';
      }
      if (data.sharing.revision !== undefined) {
        this.state.sharing.revision = Number(data.sharing.revision) || 0;
      }
    }
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

  async sendOrPost(endpoint, data, wsType = null, method = 'POST', wsData = null) {
    if (wsType && this.send({ type: wsType, ...(wsData || data) })) return true;
    try {
      const options = { method };
      if (method !== 'DELETE' && method !== 'GET') {
        options.headers = { 'Content-Type': 'application/json' };
        options.body = JSON.stringify(data ?? {});
      }
      const res = await fetch(endpoint, options);
      if (res.ok) {
        this._refreshStatusFallback();
      }
      return res.ok;
    } catch (e) {
      console.warn(`[WyrmNet] Request to ${endpoint} failed:`, e);
      return false;
    }
  }

  async _refreshStatusFallback() {
    try {
      let res = await fetch('/api/status');
      if (!res.ok) res = await fetch('/api/state');
      if (res.ok) this.store.mergeSnapshot(await res.json());
    } catch (_) { }
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
  const CARDS = ['clock', 'habits', 'calendar', 'tasks', 'reminder', 'sharing'];

  // Shared draft: the glyph picked for the next habit (also drives window.wyrmRemote).
  const draft = Vue.reactive({ glyph: '💧' });

  const pad = (n) => String(n).padStart(2, '0');
  const pad3 = (n) => String(n).padStart(3, '0');
  const padYear = (y) => String(y).padStart(4, '0');
  // Local calendar date as YYYY-MM-DD. Used everywhere so "today" can never
  // disagree with the week strip (toISOString is UTC and flips at the wrong hour).
  const dateKey = (d = new Date()) => `${padYear(d.getFullYear())}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const toLocalIsoString = (d = new Date()) => {
    const dt = d instanceof Date ? d : new Date(d);
    if (isNaN(dt.getTime())) return '';
    return `${padYear(dt.getFullYear())}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}T${pad(dt.getHours())}:${pad(dt.getMinutes())}:${pad(dt.getSeconds())}.${pad3(dt.getMilliseconds())}`;
  };

  const RECURRENCES = new Set(['once', 'daily', 'weekdays', 'custom']);
  const normalizeRecurrence = (val) => {
    const v = String(val || 'once').trim().toLowerCase();
    return RECURRENCES.has(v) ? v : 'once';
  };
  const normalizeWeekdays = (list) => {
    if (!Array.isArray(list)) return [];
    const seen = new Set();
    list.forEach((raw) => {
      const n = parseInt(raw, 10);
      if (n >= 1 && n <= 7) seen.add(n);
    });
    return Array.from(seen).sort((a, b) => a - b);
  };
  const parseIsoDate = (val) => {
    if (!val) return null;
    const d = val instanceof Date ? val : new Date(val);
    return isNaN(d.getTime()) ? null : d;
  };

  // Shared reactive wall-clock ticker so reminder countdowns stay fresh.
  const nowMs = Vue.ref(Date.now());
  setInterval(() => { nowMs.value = Date.now(); }, 15000);

  const post = (endpoint, data, type, method = 'POST', wsData = null) =>
    ws.sendOrPost(endpoint, data, type, method, wsData);

  // Brightness drags fire constantly; send at most one update per 80ms, always ending on the final value.
  let brightTimer = null;
  let brightPending = null;
  let brightLastSent = 0;

  const actions = {
    state,
    draft,
    nowMs,
    dateKey,
    toLocalIsoString,
    normalizeRecurrence,
    normalizeWeekdays,

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

    /* Reminders & Alarms */
    addReminder(payload = {}) {
      const clean = String(payload.title || '').trim();
      const rawSched = payload.scheduled_at ?? payload.scheduledAt;
      const schedDate = parseIsoDate(rawSched);
      if (!clean || !schedDate) return false;

      const recurrence = normalizeRecurrence(payload.recurrence);
      const customWeekdays = recurrence === 'custom'
        ? normalizeWeekdays(payload.custom_weekdays ?? payload.customWeekdays)
        : [];
      if (recurrence === 'custom' && customWeekdays.length === 0) return false;

      const isEnabled = payload.is_enabled !== undefined
        ? !!payload.is_enabled
        : (payload.isEnabled !== undefined ? !!payload.isEnabled : true);
      const scheduledAtIso = typeof rawSched === 'string' && rawSched.includes('T')
        ? rawSched
        : toLocalIsoString(schedDate);

      post(
        '/api/reminders',
        {
          title: clean,
          scheduled_at: scheduledAtIso,
          recurrence,
          custom_weekdays: customWeekdays,
          is_enabled: isEnabled,
        },
        'reminder_add',
        'POST',
        {
          title: clean,
          scheduled_at: scheduledAtIso,
          recurrence,
          custom_weekdays: customWeekdays,
        }
      );
      return true;
    },
    editReminder(idOrPayload, maybeFields = {}) {
      let id = idOrPayload;
      let fields = maybeFields;
      if (idOrPayload && typeof idOrPayload === 'object') {
        id = idOrPayload.id;
        fields = idOrPayload;
      }
      if (!id) return false;
      const existing = state.reminders.find((r) => r.id === id);

      const titleRaw = fields.title !== undefined ? fields.title : (existing && existing.title);
      const cleanTitle = String(titleRaw || '').trim();
      if (!cleanTitle) return false;

      const rawSched = fields.scheduled_at ?? fields.scheduledAt ?? (existing && (existing.scheduled_at ?? existing.scheduledAt));
      const schedDate = parseIsoDate(rawSched);
      if (!schedDate) return false;

      const recurrence = normalizeRecurrence(fields.recurrence ?? (existing && existing.recurrence));
      const rawDays = fields.custom_weekdays ?? fields.customWeekdays ?? (existing && (existing.custom_weekdays ?? existing.customWeekdays));
      const customWeekdays = recurrence === 'custom' ? normalizeWeekdays(rawDays) : [];
      if (recurrence === 'custom' && customWeekdays.length === 0) return false;

      const isEnabled = fields.is_enabled !== undefined
        ? !!fields.is_enabled
        : (fields.isEnabled !== undefined
          ? !!fields.isEnabled
          : (existing ? !!(existing.is_enabled ?? existing.isEnabled ?? true) : true));

      const scheduledAtIso = typeof rawSched === 'string' && rawSched.includes('T')
        ? rawSched
        : toLocalIsoString(schedDate);

      if (existing) {
        store.markPendingOnce('reminders', state.reminders);
        existing.title = cleanTitle;
        existing.scheduled_at = scheduledAtIso;
        existing.recurrence = recurrence;
        existing.custom_weekdays = customWeekdays;
        existing.is_enabled = isEnabled;
        existing.snoozed_until = null;
      }

      const body = {
        title: cleanTitle,
        scheduled_at: scheduledAtIso,
        recurrence,
        custom_weekdays: customWeekdays,
        is_enabled: isEnabled,
      };
      post(
        `/api/reminders/${encodeURIComponent(id)}`,
        body,
        'reminder_edit',
        'PUT',
        { id, ...body }
      );
      return true;
    },
    toggleReminder(id, explicitEnabled) {
      if (!id) return false;
      const r = state.reminders.find((item) => item.id === id);
      const current = r ? !!(r.is_enabled ?? r.isEnabled ?? true) : false;
      const nextEnabled = typeof explicitEnabled === 'boolean' ? explicitEnabled : !current;
      if (r) {
        store.markPendingOnce('reminders', state.reminders);
        r.is_enabled = nextEnabled;
      }
      post(
        `/api/reminders/${encodeURIComponent(id)}`,
        { is_enabled: nextEnabled },
        'reminder_toggle',
        'PUT',
        { id, is_enabled: nextEnabled }
      );
      return true;
    },
    deleteReminder(id) {
      if (!id) return false;
      store.markPendingOnce('reminders', state.reminders);
      state.reminders = state.reminders.filter((item) => item.id !== id);
      post(
        `/api/reminders/${encodeURIComponent(id)}`,
        {},
        'reminder_delete',
        'DELETE',
        { id }
      );
      return true;
    },
    dismissActiveAlarm() {
      store.markPendingOnce('activeAlarm', state.activeAlarm);
      state.activeAlarm = null;
      post('/api/reminders/alarm/dismiss', {}, 'reminder_dismiss_alarm', 'POST', {});
      return true;
    },
    snoozeActiveAlarm(minutes = 10) {
      const mins = Math.max(1, parseInt(minutes, 10) || 10);
      store.markPendingOnce('activeAlarm', state.activeAlarm);
      state.activeAlarm = null;
      post('/api/reminders/alarm/snooze', { minutes: mins }, 'reminder_snooze_alarm', 'POST', { minutes: mins });
      return true;
    },
    formatReminderTime(dateOrIso) {
      const d = parseIsoDate(dateOrIso);
      if (!d) return '';
      const hh = d.getHours();
      const mm = pad(d.getMinutes());
      if (state.settings.is24HourFormat) {
        return `${pad(hh)}:${mm}`;
      }
      const suffix = hh >= 12 ? 'PM' : 'AM';
      const h12 = hh % 12 || 12;
      return `${h12}:${mm} ${suffix}`;
    },
    isReminderSnoozed(reminder, refNow = new Date(nowMs.value)) {
      if (!reminder) return false;
      const enabled = reminder.is_enabled ?? reminder.isEnabled ?? true;
      if (!enabled) return false;
      const now = refNow instanceof Date ? refNow : new Date(refNow);
      const snoozed = parseIsoDate(reminder.snoozed_until ?? reminder.snoozedUntil);
      return !!(snoozed && snoozed.getTime() > now.getTime());
    },
    nextReminderFireDate(reminder, refNow = new Date(nowMs.value)) {
      if (!reminder) return null;
      const enabled = reminder.is_enabled ?? reminder.isEnabled ?? true;
      if (!enabled) return null;

      const now = refNow instanceof Date ? refNow : new Date(refNow);
      const snoozed = parseIsoDate(reminder.snoozed_until ?? reminder.snoozedUntil);
      if (snoozed && snoozed.getTime() > now.getTime()) {
        return snoozed;
      }

      const scheduled = parseIsoDate(reminder.scheduled_at ?? reminder.scheduledAt);
      if (!scheduled) return null;
      const lastTriggered = parseIsoDate(reminder.last_triggered_at ?? reminder.lastTriggeredAt);
      const recurrence = normalizeRecurrence(reminder.recurrence);

      if (recurrence === 'once') {
        if (scheduled.getTime() > now.getTime() && (!lastTriggered || lastTriggered.getTime() < scheduled.getTime())) {
          return scheduled;
        }
        return null;
      }

      const customDays = normalizeWeekdays(reminder.custom_weekdays ?? reminder.customWeekdays);
      if (recurrence === 'custom' && customDays.length === 0) return null;

      const hour = scheduled.getHours();
      const minute = scheduled.getMinutes();
      for (let offset = 0; offset <= 14; offset++) {
        const candidate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, hour, minute, 0, 0);
        const isoDay = candidate.getDay() === 0 ? 7 : candidate.getDay();
        const matches =
          recurrence === 'daily' ||
          (recurrence === 'weekdays' && isoDay >= 1 && isoDay <= 5) ||
          (recurrence === 'custom' && customDays.includes(isoDay));
        if (!matches) continue;
        if (candidate.getTime() > now.getTime() && (!lastTriggered || candidate.getTime() > lastTriggered.getTime())) {
          return candidate;
        }
      }
      return null;
    },
    nextUpcomingReminder(refNow = new Date(nowMs.value)) {
      let best = null;
      (state.reminders || []).forEach((r) => {
        const fireAt = actions.nextReminderFireDate(r, refNow);
        if (!fireAt) return;
        if (!best || fireAt.getTime() < best.fireAt.getTime()) {
          best = { reminder: r, fireAt, isSnoozed: actions.isReminderSnoozed(r, refNow) };
        }
      });
      return best;
    },
    formatRelativeDuration(targetDate, refNow = new Date(nowMs.value)) {
      const target = parseIsoDate(targetDate);
      if (!target) return '';
      const now = refNow instanceof Date ? refNow : new Date(refNow);
      const diffMs = target.getTime() - now.getTime();
      if (diffMs <= 0) return 'Now';
      if (diffMs < 60000) return 'In <1m';

      const totalMins = Math.max(1, Math.round(diffMs / 60000));
      if (totalMins < 60) return `In ${totalMins}m`;

      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const targetStart = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const dayDiff = Math.round((targetStart.getTime() - todayStart.getTime()) / 86400000);

      if (dayDiff === 0) {
        const hrs = Math.floor(totalMins / 60);
        const mins = totalMins % 60;
        return mins ? `In ${hrs}h ${mins}m` : `In ${hrs}h`;
      }
      if (dayDiff === 1) return 'Tomorrow';
      return `In ${dayDiff}d`;
    },
    reminderCountdown(reminder, refNow = new Date(nowMs.value)) {
      if (!reminder) return '';
      const enabled = reminder.is_enabled ?? reminder.isEnabled ?? true;
      if (!enabled) {
        const recurrence = normalizeRecurrence(reminder.recurrence);
        const last = parseIsoDate(reminder.last_triggered_at ?? reminder.lastTriggeredAt);
        return recurrence === 'once' && last ? 'Done' : 'Paused';
      }
      const next = actions.nextReminderFireDate(reminder, refNow);
      if (!next) return 'Scheduled';
      const rel = actions.formatRelativeDuration(next, refNow);
      return actions.isReminderSnoozed(reminder, refNow) ? `Snoozed · ${rel}` : rel;
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
    travelToDate(date) {
      const d = date instanceof Date ? date : new Date(date);
      if (isNaN(d.getTime())) return false;
      const key = dateKey(d);
      store.markPendingOnce('calendar', state.calendar);
      state.calendar.selectedDate = d.toISOString();
      const vm = new Date(d.getFullYear(), d.getMonth(), 1);
      if (d.getFullYear() >= 0 && d.getFullYear() < 100) vm.setFullYear(d.getFullYear());
      state.calendar.viewMonth = vm.toISOString();
      post('/api/calendar/travel', { date: key }, 'travel_to_date');
      return true;
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

    /* Local File Sharing */
    formatByteSize(bytes) {
      const n = Number(bytes) || 0;
      if (n < 1024) return n + ' B';
      const units = ['KB', 'MB', 'GB', 'TB'];
      let val = n / 1024;
      let idx = 0;
      while (val >= 1024 && idx < units.length - 1) {
        val /= 1024;
        idx++;
      }
      return val.toFixed(val >= 100 ? 0 : 1) + ' ' + units[idx];
    },
    isPreviewableMime(mime) {
      const m = String(mime || '').toLowerCase();
      return (
        m.startsWith('image/') ||
        m.startsWith('audio/') ||
        m.startsWith('video/') ||
        m.startsWith('text/') ||
        m.startsWith('application/json') ||
        m.startsWith('application/xml') ||
        m.startsWith('application/pdf')
      );
    },
    sharingDownloadUrl(relativePath, inline = false) {
      const token = encodeURIComponent(state.sharing.token || '');
      const pathParam = encodeURIComponent(relativePath || '');
      return `/api/sharing/download?path=${pathParam}&token=${token}${inline ? '&inline=1' : ''}`;
    },
    sharingFullDownloadUrl(relativePath) {
      return window.location.origin + actions.sharingDownloadUrl(relativePath, false);
    },
    _setSharingToken(token) {
      state.sharing.token = token || '';
      try {
        if (token) sessionStorage.setItem('wyrm_sharing_token', token);
        else sessionStorage.removeItem('wyrm_sharing_token');
      } catch (_) { }
    },
    sharingLogout(reason = '') {
      actions._setSharingToken('');
      state.sharing.entries = [];
      state.sharing.currentPath = '';
      state.sharing.totalBytes = 0;
      state.sharing.error = reason;
    },
    async sharingAuth(password) {
      const clean = String(password || '').trim();
      if (!clean) {
        state.sharing.error = 'Enter the sharing password shown on the tablet.';
        return false;
      }
      state.sharing.error = '';
      try {
        const res = await fetch('/api/sharing/auth', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ password: clean }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.token) {
          state.sharing.error = data.error || 'Invalid sharing password.';
          return false;
        }
        actions._setSharingToken(data.token);
        if (data.has_permission !== undefined) {
          state.sharing.hasPermission = !!data.has_permission;
        }
        await actions.sharingFetchFiles('');
        return true;
      } catch (err) {
        state.sharing.error = 'Could not reach the tablet server.';
        return false;
      }
    },
    async sharingFetchFiles(path = state.sharing.currentPath) {
      if (!state.sharing.token) return false;
      state.sharing.isLoading = true;
      state.sharing.error = '';
      try {
        const params = new URLSearchParams({
          path: path || '',
          sort: state.sharing.sortBy,
          asc: String(state.sharing.sortAscending),
        });
        const res = await fetch('/api/sharing/files?' + params.toString(), {
          headers: { 'X-Sharing-Token': state.sharing.token },
        });
        if (res.status === 401) {
          actions.sharingLogout('Session expired or password changed on tablet.');
          return false;
        }
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
          state.sharing.error = data.error || 'Could not load folder.';
          return false;
        }
        state.sharing.currentPath = data.path || '';
        state.sharing.entries = Array.isArray(data.entries) ? data.entries : [];
        state.sharing.totalBytes = Number(data.total_bytes) || 0;
        return true;
      } catch (_) {
        state.sharing.error = 'Network error loading shared files.';
        return false;
      } finally {
        state.sharing.isLoading = false;
      }
    },
    sharingSetSort(sortBy) {
      if (state.sharing.sortBy === sortBy) {
        state.sharing.sortAscending = !state.sharing.sortAscending;
      } else {
        state.sharing.sortBy = sortBy;
        state.sharing.sortAscending = true;
      }
      actions.sharingFetchFiles(state.sharing.currentPath);
    },
    async _sharingJsonPost(endpoint, payload) {
      if (!state.sharing.token) return false;
      state.sharing.error = '';
      try {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Sharing-Token': state.sharing.token,
          },
          body: JSON.stringify(payload),
        });
        if (res.status === 401) {
          actions.sharingLogout('Session expired or password changed on tablet.');
          return false;
        }
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
          state.sharing.error = data.error || 'Action failed.';
          return false;
        }
        await actions.sharingFetchFiles(state.sharing.currentPath);
        return true;
      } catch (_) {
        state.sharing.error = 'Network error communicating with tablet.';
        return false;
      }
    },
    sharingMkdir(name) {
      return actions._sharingJsonPost('/api/sharing/mkdir', {
        path: state.sharing.currentPath,
        name: String(name || '').trim(),
      });
    },
    sharingRename(relativePath, newName) {
      return actions._sharingJsonPost('/api/sharing/rename', {
        path: relativePath,
        new_name: String(newName || '').trim(),
      });
    },
    sharingMove(relativePath, targetDir) {
      return actions._sharingJsonPost('/api/sharing/move', {
        path: relativePath,
        target_dir: targetDir,
      });
    },
    sharingDelete(relativePath) {
      return actions._sharingJsonPost('/api/sharing/delete', { path: relativePath });
    },
    async sharingUploadFiles(fileList) {
      const files = Array.from(fileList || []);
      if (!files.length || !state.sharing.token) return;
      const targetDir = state.sharing.currentPath || '';
      const queued = files.map((file, index) => ({
        id: Date.now() + '_' + index + '_' + file.name,
        file,
        name: file.name,
        size: file.size,
        progress: 0,
        status: 'queued',
        error: '',
      }));
      state.sharing.uploads.unshift(...queued.map(({ file, ...rest }) => rest));

      for (const item of queued) {
        const track = state.sharing.uploads.find((u) => u.id === item.id);
        if (!track) continue;
        track.status = 'uploading';
        const ok = await new Promise((resolve) => {
          const xhr = new XMLHttpRequest();
          const url = '/api/sharing/upload?path=' + encodeURIComponent(targetDir);
          xhr.open('POST', url, true);
          xhr.setRequestHeader('X-Sharing-Token', state.sharing.token);
          xhr.setRequestHeader('X-File-Name', encodeURIComponent(item.name));
          xhr.upload.onprogress = (ev) => {
            if (ev.lengthComputable && ev.total > 0) {
              track.progress = Math.min(100, Math.round((ev.loaded / ev.total) * 100));
            }
          };
          xhr.onload = () => {
            if (xhr.status === 401) {
              actions.sharingLogout('Session expired or password changed on tablet.');
              track.status = 'error';
              track.error = 'Unauthorized';
              resolve(false);
              return;
            }
            if (xhr.status >= 200 && xhr.status < 300) {
              track.progress = 100;
              track.status = 'done';
              resolve(true);
            } else {
              let msg = 'HTTP ' + xhr.status;
              try {
                const body = JSON.parse(xhr.responseText);
                if (body.error) msg = body.error;
              } catch (_) { }
              track.status = 'error';
              track.error = msg;
              resolve(false);
            }
          };
          xhr.onerror = () => {
            track.status = 'error';
            track.error = 'Connection lost';
            resolve(false);
          };
          xhr.send(item.file);
        });
        if (ok) {
          await actions.sharingFetchFiles(state.sharing.currentPath);
        }
      }
    },
    sharingClearFinishedUploads() {
      state.sharing.uploads = state.sharing.uploads.filter((u) => u.status === 'uploading' || u.status === 'queued');
    },
  };

  // Auto-refresh authenticated sharing listing on tab open or tablet revision bump.
  Vue.watch(
    () => [state.currentChannel, state.sharing.revision, state.sharing.token],
    ([channel, _rev, token]) => {
      if (channel === 'sharing' && token && state.sharing.hasPermission) {
        actions.sharingFetchFiles(state.sharing.currentPath);
      }
    }
  );

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
    let res = await fetch('/api/status');
    if (!res.ok) res = await fetch('/api/state');
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
  travelToDate: (date) => wyrm.travelToDate(date),
  createHabit: (title, type, target, glyph) =>
    wyrm.createHabit({ title, type: type || 'binary', target: target || 1, glyph: glyph || '💧' }),
  selectHabitGlyph: (glyph) => { wyrm.draft.glyph = glyph; },
  toggleHabit: (id) => wyrm.toggleHabit(id),
  stepHabit: (id, delta) => wyrm.stepHabit(id, delta),
  deleteHabit: (id) => wyrm.deleteHabit(id),
  addReminder: (payload) => wyrm.addReminder(payload),
  editReminder: (idOrPayload, fields) => wyrm.editReminder(idOrPayload, fields),
  toggleReminder: (id, isEnabled) => wyrm.toggleReminder(id, isEnabled),
  deleteReminder: (id) => wyrm.deleteReminder(id),
  dismissActiveAlarm: () => wyrm.dismissActiveAlarm(),
  snoozeActiveAlarm: (minutes) => wyrm.snoozeActiveAlarm(minutes),
  setBrightness: (val) => wyrm.setBrightness(val),
  exportBackup: () => wyrm.exportBackup(),
  importBackup: (json) => wyrm.importBackup(json),
};
