/**
 * Wyrm Desk — Remote Companion Engine
 * Grounded in Apple Human Interface Guidelines & Dieter Rams Functionalism
 * Architecture: ES6 Reactive Store, Persistent WebSocket Transport, REST Fallback, Tactile Haptics
 */

/**
 * Tactile Haptic Feedback Utility (Safari & WebKit Vibration API)
 */
const WyrmHaptics = {
  tap() {
    try {
      if ('vibrate' in navigator) navigator.vibrate(10);
    } catch (_) {}
  },
  selection() {
    try {
      if ('vibrate' in navigator) navigator.vibrate(15);
    } catch (_) {}
  },
  success() {
    try {
      if ('vibrate' in navigator) navigator.vibrate([12, 40, 18]);
    } catch (_) {}
  },
  impact() {
    try {
      if ('vibrate' in navigator) navigator.vibrate(22);
    } catch (_) {}
  },
};

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
        startWeekOnMonday: false,
      },
      display: {
        brightness: 1.0,
      },
      tasks: [],
      habits: [],
      calendar: {
        today: new Date().toISOString(),
        selectedDate: new Date().toISOString(),
        viewMonth: new Date().toISOString(),
        yearProgress: 0,
        quarterProgress: 0,
        dayOfYear: 1,
        daysInYear: 365,
        currentQuarter: 1,
        startWeekOnMonday: false,
        milestones: [],
      },
      activeFilter: 'all',
      isConnected: false,
      theme: localStorage.getItem('wyrm_theme') || 'auto',
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
      display: { ...this.state.display, ...(partialState.display || {}) },
      tasks: partialState.tasks !== undefined ? partialState.tasks : this.state.tasks,
      habits: partialState.habits !== undefined ? partialState.habits : this.state.habits,
      calendar: partialState.calendar !== undefined ? { ...this.state.calendar, ...partialState.calendar } : this.state.calendar,
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
        WyrmHaptics.success();
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
    WyrmHaptics.selection();
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

  scrollToCard(card) {
    const message = JSON.stringify({ type: 'scroll_to_card', card });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/scroll', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ card }),
      }).catch(() => {});
    }
  }

  sendSettingsMutation(settingsPayload) {
    WyrmHaptics.selection();
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

  setDisplay(displayPayload) {
    const message = JSON.stringify({
      type: 'set_display',
      ...displayPayload,
    });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/display', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(displayPayload),
      }).catch(() => {});
    }
  }

  createTask(title, priority = 'normal') {
    WyrmHaptics.success();
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
    WyrmHaptics.tap();
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
    WyrmHaptics.impact();
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

  createMilestone(title, targetDate, isPinned = false) {
    WyrmHaptics.success();
    const message = JSON.stringify({ type: 'create_milestone', title, targetDate, isPinned });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/calendar/milestones', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, target_date: targetDate, is_pinned: isPinned }),
      }).catch(() => {});
    }
  }

  deleteMilestone(id) {
    WyrmHaptics.impact();
    const message = JSON.stringify({ type: 'delete_milestone', id });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/calendar/milestones/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      }).catch(() => {});
    }
  }

  togglePinMilestone(id) {
    WyrmHaptics.selection();
    const message = JSON.stringify({ type: 'toggle_pin_milestone', id });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/calendar/milestones/pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      }).catch(() => {});
    }
  }

  createHabit(title, habitType = 'binary', targetValue = 1, unit = null, iconName = 'bolt') {
    WyrmHaptics.success();
    const message = JSON.stringify({
      type: 'create_habit',
      title,
      habit_type: habitType,
      target_value: targetValue,
      unit,
      icon_name: iconName,
    });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/habits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title,
          habit_type: habitType,
          target_value: targetValue,
          unit,
          icon_name: iconName,
        }),
      }).catch(() => {});
    }
  }

  toggleHabit(id, date = null) {
    WyrmHaptics.tap();
    const message = JSON.stringify({ type: 'toggle_habit', id, date });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/habits/toggle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, date }),
      }).catch(() => {});
    }
  }

  stepHabit(id, delta = 1, date = null) {
    WyrmHaptics.selection();
    const message = JSON.stringify({ type: 'step_habit', id, delta, date });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/habits/step', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, delta, date }),
      }).catch(() => {});
    }
  }

  deleteHabit(id) {
    WyrmHaptics.impact();
    const message = JSON.stringify({ type: 'delete_habit', id });

    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(message);
    } else {
      fetch('/api/habits/delete', {
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
          display: payload.display !== undefined ? payload.display : this.store.getState().display,
          tasks: payload.tasks !== undefined ? payload.tasks : this.store.getState().tasks,
          habits: payload.habits !== undefined ? payload.habits : this.store.getState().habits,
          calendar: payload.calendar !== undefined ? payload.calendar : this.store.getState().calendar,
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
    this._setupCardClickListeners();
    this._initMilestoneDateInput();
    this._applyTheme(this.store.getState().theme || 'auto');
    this.initSideNav();
  }

  _cacheDomElements() {
    this.cardsStream = document.getElementById('mainContent');
    this.networkBadge = document.getElementById('networkBadge');
    this.networkLabel = document.getElementById('networkLabel');
    this.themeToggleBtn = document.getElementById('themeToggleBtn');
    this.timeFormatToggle = document.getElementById('timeFormatToggle');
    this.fontSizeDisplay = document.getElementById('fontSizeDisplay');
    this.cardClock = document.getElementById('card-clock');
    this.tasksList = document.getElementById('tasksList');
    this.tasksCounter = document.getElementById('tasksCounter');
    this.taskInput = document.getElementById('taskInput');
    this.taskPriority = document.getElementById('taskPriority');

    // Calendar DOM elements
    this.startWeekToggle = document.getElementById('startWeekToggle');
    this.dayOfYearBadge = document.getElementById('dayOfYearBadge');
    this.yearProgressLabel = document.getElementById('yearProgressLabel');
    this.yearProgressFill = document.getElementById('yearProgressFill');
    this.quarterProgressLabel = document.getElementById('quarterProgressLabel');
    this.quarterProgressFill = document.getElementById('quarterProgressFill');
    this.webCalMonthYear = document.getElementById('webCalMonthYear');
    this.webCalWeekdays = document.getElementById('webCalWeekdays');
    this.webCalDays = document.getElementById('webCalDays');
    this.webCalSelectedStatus = document.getElementById('webCalSelectedStatus');
    this.milestonesCounter = document.getElementById('milestonesCounter');
    this.milestoneTitleInput = document.getElementById('milestoneTitleInput');
    this.milestoneDateInput = document.getElementById('milestoneDateInput');
    this.milestoneNativePicker = document.getElementById('milestoneNativePicker');
    this.milestonePinCheckbox = document.getElementById('milestonePinCheckbox');
    this.milestonesList = document.getElementById('milestonesList');

    // Habits DOM elements
    this.habitsCounter = document.getElementById('habitsCounter');
    this.habitTitleInput = document.getElementById('habitTitleInput');
    this.habitTypeSelect = document.getElementById('habitTypeSelect');
    this.habitTargetInput = document.getElementById('habitTargetInput');
    this.habitUnitInput = document.getElementById('habitUnitInput');
    this.habitsList = document.getElementById('habitsList');
    this.selectedHabitGlyph = 'bolt';

    // Display DOM elements
    this.brightnessSlider = document.getElementById('brightnessSlider');
    this.brightnessValueBadge = document.getElementById('brightnessValueBadge');

    this.webCalViewDate = new Date();
    this.webCalSelectedDate = new Date();

    this.cardAll = document.getElementById('card-all');
    this.allCardsStatusBadge = document.getElementById('allCardsStatusBadge');
    this.allCardsButtons = {
      small: document.getElementById('all-small'),
      medium: document.getElementById('all-medium'),
      fullscreen: document.getElementById('all-fullscreen'),
    };

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

    this.mobileTabItems = document.querySelectorAll('.mobile-tab-item');
    this.sideNavItems = document.querySelectorAll('.side-nav-item');
    this.sideNavToggle = document.getElementById('sideNavToggle');
  }

  _setupCardClickListeners() {
    document.addEventListener('click', (event) => {
      const cardEl = event.target.closest('.layout-card');
      if (!cardEl) return;

      // Ignore clicks originating from interactive input/action controls
      const ignoredSelector = 'input, select, textarea, .task-checkbox, .task-delete-btn, .task-add-btn, .milestone-del-btn, .milestone-pin-btn, .switch-pill, .stepper-control, .web-cal-day-cell, .cal-nav-btn, .habit-toggle-btn, .habit-del-btn, .glyph-chip';
      if (event.target.closest(ignoredSelector)) {
        return;
      }

      // If clicked on size button (.segment-btn), setCardSize handles sizing and scroll.
      if (event.target.closest('.segment-btn')) {
        return;
      }

      const cardCategory = cardEl.getAttribute('data-card');
      if (cardCategory === 'all') {
        this.scrollToCard('clock', cardEl);
      } else if (cardCategory) {
        this.scrollToCard(cardCategory, cardEl);
      }
    });
  }

  _initMilestoneDateInput() {
    if (!this.milestoneDateInput) return;

    // Default to today's date formatted as dd/mm/yyyy
    const today = new Date();
    const day = String(today.getDate()).padStart(2, '0');
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const year = today.getFullYear();
    this.milestoneDateInput.value = `${day}/${month}/${year}`;

    // Auto-format typing to enforce dd/mm/yyyy with slashes
    this.milestoneDateInput.addEventListener('input', (e) => {
      let val = e.target.value.replace(/\D/g, '');
      if (val.length > 8) val = val.substring(0, 8);

      let formatted = '';
      if (val.length > 4) {
        formatted = `${val.substring(0, 2)}/${val.substring(2, 4)}/${val.substring(4)}`;
      } else if (val.length > 2) {
        formatted = `${val.substring(0, 2)}/${val.substring(2)}`;
      } else {
        formatted = val;
      }
      e.target.value = formatted;
    });

    this.milestoneDateInput.addEventListener('keydown', (e) => {
      if (e.key === 'Backspace') {
        const val = this.milestoneDateInput.value;
        const selStart = this.milestoneDateInput.selectionStart;
        const selEnd = this.milestoneDateInput.selectionEnd;
        if (selStart === selEnd && (selStart === 3 || selStart === 6) && val[selStart - 1] === '/') {
          e.preventDefault();
          this.milestoneDateInput.value = val.substring(0, selStart - 2) + val.substring(selStart);
          this.milestoneDateInput.setSelectionRange(selStart - 2, selStart - 2);
        }
      }
    });
  }

  scrollToCard(cardName, visualTargetEl = null) {
    if (!cardName) return;
    this.wsManager.scrollToCard(cardName);

    // Provide subtle active tap visual feedback on the card
    const target = visualTargetEl || this.cardMap[cardName] || document.querySelector(`.layout-card[data-card="${cardName}"]`);
    if (target) {
      target.classList.remove('card-tapped');
      void target.offsetWidth;
      target.classList.add('card-tapped');
      setTimeout(() => {
        target.classList.remove('card-tapped');
      }, 350);
    }
  }

  setCardFilter(filterName) {
    WyrmHaptics.selection();
    this.store.setState({ activeFilter: filterName });
    if (filterName && filterName !== 'all') {
      this.scrollToCard(filterName, this.cardMap[filterName]);
    }
  }

  setCardSize(card, size) {
    this.store.setState({ layout: { [card]: size } });
    this.wsManager.sendLayoutMutation(card, size);
    this.scrollToCard(card, this.cardMap[card]);
  }

  setAllCardsSize(size) {
    const cards = ['clock', 'habits', 'calendar', 'tasks'];
    const updatedLayout = {};
    cards.forEach((card) => {
      updatedLayout[card] = size;
      this.wsManager.sendLayoutMutation(card, size);
    });
    this.store.setState({ layout: updatedLayout });
    this.scrollToCard('clock', this.cardAll);
  }

  toggleTimeFormat() {
    const is24Hour = !this.store.getState().settings.is24HourFormat;
    this.store.setState({ settings: { is24HourFormat: is24Hour } });
    this.wsManager.sendSettingsMutation({ is24HourFormat: is24Hour });
  }

  toggleStartWeekOnMonday() {
    const current = !!(this.store.getState().settings && this.store.getState().settings.startWeekOnMonday);
    const updated = !current;
    this.store.setState({ settings: { startWeekOnMonday: updated } });
    this.wsManager.sendSettingsMutation({ startWeekOnMonday: updated });
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

  previewBrightness(value) {
    const pct = parseInt(value, 10);
    if (isNaN(pct)) return;
    if (this.brightnessValueBadge) this.brightnessValueBadge.textContent = `${pct}%`;
    this._paintBrightnessSlider(pct);
  }

  setBrightness(value) {
    const pct = parseInt(value, 10);
    if (isNaN(pct)) return;
    const clamped = Math.max(5, Math.min(100, pct));
    const brightness = clamped / 100;
    this.store.setState({ display: { brightness } });
    this.wsManager.setDisplay({ brightness });
    WyrmHaptics.selection();
  }

  _paintBrightnessSlider(pct) {
    if (!this.brightnessSlider) return;
    // The native thumb slides across the (min..max) range, so scale the amber fill
    // by the same fraction. This makes it terminate under the thumb centre, hidden
    // behind the circle, instead of showing past the circle at the right end.
    const min = Number(this.brightnessSlider.min) || 0;
    const max = Number(this.brightnessSlider.max) || 100;
    const span = max - min || 1;
    const fraction = Math.max(0, Math.min(1, (pct - min) / span));
    this.brightnessSlider.style.setProperty('--fill', `${fraction * 100}%`);
  }

  cycleTheme() {
    WyrmHaptics.selection();
    const current = this.store.getState().theme || 'auto';
    let next = 'dark';
    if (current === 'dark') next = 'light';
    else if (current === 'light') next = 'dark'; // cycles dark <-> light smoothly
    this.store.setState({ theme: next });
    localStorage.setItem('wyrm_theme', next);
    this._applyTheme(next);
  }

  _applyTheme(theme) {
    if (theme === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
    } else if (theme === 'dark') {
      document.documentElement.setAttribute('data-theme', 'dark');
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
  }

  /**
   * Initialises the adaptive sidebar rail. The rail auto-expands on wide
   * canvases and auto-collapses when space is tight; the dedicated toggle lets
   * the user pin a preference, which then persists across sessions.
   */
  initSideNav() {
    this._railUserPref = localStorage.getItem('wyrm_rail');
    this._applySideNav();
    window.addEventListener('resize', () => this._applySideNav(), { passive: true });
  }

  _applySideNav() {
    const width = window.innerWidth;
    // Auto-expand only when there is comfortable room; always collapse when the
    // viewport is tight, regardless of any pinned preference.
    const autoExpanded = width >= 1180;
    const tooNarrow = width < 1024;
    const expanded = tooNarrow
      ? false
      : this._railUserPref
        ? this._railUserPref === 'expanded'
        : autoExpanded;

    document.body.dataset.rail = expanded ? 'expanded' : 'collapsed';

    if (this.sideNavToggle) {
      const label = expanded ? 'Collapse navigation' : 'Expand navigation';
      this.sideNavToggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      this.sideNavToggle.setAttribute('title', label);
      this.sideNavToggle.setAttribute('aria-label', label);
    }
  }

  toggleSideNav() {
    WyrmHaptics.selection();
    const expanded = document.body.dataset.rail === 'expanded';
    this._railUserPref = expanded ? 'collapsed' : 'expanded';
    localStorage.setItem('wyrm_rail', this._railUserPref);
    this._applySideNav();
  }

  prevWebMonth() {
    WyrmHaptics.tap();
    this.webCalViewDate.setMonth(this.webCalViewDate.getMonth() - 1);
    this._renderWebCalendarWidget(this.store.getState());
  }

  nextWebMonth() {
    WyrmHaptics.tap();
    this.webCalViewDate.setMonth(this.webCalViewDate.getMonth() + 1);
    this._renderWebCalendarWidget(this.store.getState());
  }

  todayWebMonth() {
    WyrmHaptics.selection();
    this.webCalViewDate = new Date();
    this.webCalSelectedDate = new Date();
    this._renderWebCalendarWidget(this.store.getState());
  }

  promptTravelDate() {
    WyrmHaptics.tap();
    const input = document.getElementById('webCalTravelInput');
    if (input) {
      if (typeof input.showPicker === 'function') {
        try {
          input.showPicker();
          return;
        } catch (_) {}
      }
      input.focus();
      input.click();
    }
  }

  travelWebDate(dateStr) {
    if (!dateStr) return;
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      const year = parseInt(parts[0], 10);
      const month = parseInt(parts[1], 10) - 1;
      const day = parseInt(parts[2], 10);
      this.webCalViewDate = new Date(year, month, 1);
      this.webCalSelectedDate = new Date(year, month, day);
      this._renderWebCalendarWidget(this.store.getState());
    }
  }

  selectWebDate(year, month, day) {
    WyrmHaptics.tap();
    this.webCalSelectedDate = new Date(year, month, day);
    this._renderWebCalendarWidget(this.store.getState());
  }

  pickMilestoneDate() {
    WyrmHaptics.tap();
    const picker = this.milestoneNativePicker || document.getElementById('milestoneNativePicker');
    if (picker) {
      if (this.milestoneDateInput && this.milestoneDateInput.value) {
        const parts = this.milestoneDateInput.value.trim().split('/');
        if (parts.length === 3 && parts[2].length === 4) {
          const d = parts[0].padStart(2, '0');
          const m = parts[1].padStart(2, '0');
          const y = parts[2];
          picker.value = `${y}-${m}-${d}`;
        }
      }
      if (typeof picker.showPicker === 'function') {
        try {
          picker.showPicker();
          return;
        } catch (_) {}
      }
      picker.focus();
      picker.click();
    }
  }

  onMilestonePickerChange(isoVal) {
    if (!isoVal || !this.milestoneDateInput) return;
    const parts = isoVal.split('-');
    if (parts.length === 3) {
      const year = parts[0];
      const month = parts[1].padStart(2, '0');
      const day = parts[2].padStart(2, '0');
      this.milestoneDateInput.value = `${day}/${month}/${year}`;
      WyrmHaptics.selection();
    }
  }

  addMilestone() {
    if (!this.milestoneTitleInput) return;
    const title = this.milestoneTitleInput.value.trim();
    if (!title) return;

    let targetDateIso = new Date().toISOString().split('T')[0];
    const rawVal = this.milestoneDateInput ? this.milestoneDateInput.value.trim() : '';

    if (rawVal) {
      if (rawVal.includes('/')) {
        const parts = rawVal.split('/');
        if (parts.length === 3) {
          const day = parts[0].padStart(2, '0');
          const month = parts[1].padStart(2, '0');
          const year = parts[2].length === 2 ? `20${parts[2]}` : parts[2];
          targetDateIso = `${year}-${month}-${day}`;
        }
      } else if (rawVal.includes('-')) {
        targetDateIso = rawVal;
      }
    }

    const isPinned = this.milestonePinCheckbox ? this.milestonePinCheckbox.checked : false;

    this.wsManager.createMilestone(title, targetDateIso, isPinned);
    this.milestoneTitleInput.value = '';
    if (this.milestonePinCheckbox) this.milestonePinCheckbox.checked = false;

    // Reset date input to today in dd/mm/yyyy format
    const today = new Date();
    const day = String(today.getDate()).padStart(2, '0');
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const year = today.getFullYear();
    if (this.milestoneDateInput) {
      this.milestoneDateInput.value = `${day}/${month}/${year}`;
    }
  }

  deleteMilestone(id) {
    this.wsManager.deleteMilestone(id);
  }

  togglePinMilestone(id) {
    this.wsManager.togglePinMilestone(id);
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

  onHabitTypeChange(value) {
    const isNumeric = value === 'numeric';
    if (this.habitTargetInput) this.habitTargetInput.style.display = isNumeric ? 'inline-block' : 'none';
    if (this.habitUnitInput) this.habitUnitInput.style.display = isNumeric ? 'inline-block' : 'none';
  }

  selectHabitGlyph(glyph) {
    WyrmHaptics.tap();
    this.selectedHabitGlyph = glyph || 'bolt';
    const chips = document.querySelectorAll('#habitGlyphPicker .glyph-chip');
    chips.forEach((c) => {
      const isSelected = c.getAttribute('data-glyph') === this.selectedHabitGlyph;
      c.classList.toggle('selected', isSelected);
      c.setAttribute('aria-checked', isSelected ? 'true' : 'false');
    });
  }

  addHabit() {
    if (!this.habitTitleInput) return;
    const title = this.habitTitleInput.value.trim();
    if (!title) return;

    const type = this.habitTypeSelect ? this.habitTypeSelect.value : 'binary';
    const targetValue = this.habitTargetInput ? parseInt(this.habitTargetInput.value, 10) || 1 : 1;
    const unit = this.habitUnitInput && this.habitUnitInput.value.trim() ? this.habitUnitInput.value.trim() : null;
    const iconName = this.selectedHabitGlyph || 'bolt';

    this.wsManager.createHabit(title, type, targetValue, unit, iconName);
    this.habitTitleInput.value = '';
    if (this.habitUnitInput) this.habitUnitInput.value = '';
  }

  toggleHabit(id) {
    this.wsManager.toggleHabit(id);
  }

  stepHabit(id, delta) {
    this.wsManager.stepHabit(id, delta);
  }

  deleteHabit(id) {
    this.wsManager.deleteHabit(id);
  }

  render(state) {
    this._renderNetworkStatus(state);
    this._renderPageSwitcher(state);
    this._renderCards(state);
    this._render24HourToggle(state);
    this._renderFontSize(state);
    this._renderDisplay(state);
    this._renderTasks(state);
    this._renderCalendar(state);
    this._renderHabits(state);
  }

  _renderNetworkStatus(state) {
    const connected = !!state.isConnected;

    // Multiple telemetry badges may exist (top bar + sidebar rail).
    document.querySelectorAll('.network-badge').forEach((badge) => {
      badge.classList.toggle('connected', connected);
    });
    document.querySelectorAll('.network-label').forEach((label) => {
      label.textContent = connected ? 'LIVE' : 'CONNECTING...';
    });
  }

  _renderPageSwitcher(state) {
    const activeFilter = state.activeFilter || 'all';

    // Synchronize page data attribute on body for scoped CSS rules
    document.body.setAttribute('data-active-page', activeFilter);

    // Publish the active view on the card stream so the bento template applies
    if (this.cardsStream) {
      this.cardsStream.setAttribute('data-view', activeFilter);
    }

    // Update desktop capsule tabs
    Object.keys(this.tabButtons).forEach((key) => {
      const btn = this.tabButtons[key];
      if (btn) {
        const isActive = key === activeFilter;
        btn.classList.toggle('active', isActive);
        btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
      }
    });

    // Update mobile bottom tab bar items
    if (this.mobileTabItems) {
      this.mobileTabItems.forEach((tabItem) => {
        const tabKey = tabItem.getAttribute('data-tab');
        const isActive = tabKey === activeFilter;
        tabItem.classList.toggle('active', isActive);
        tabItem.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });
    }

    // Update sidebar rail items
    if (this.sideNavItems) {
      this.sideNavItems.forEach((item) => {
        const tabKey = item.getAttribute('data-tab');
        const isActive = tabKey === activeFilter;
        item.classList.toggle('active', isActive);
        item.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });
    }

    // Update card stream visibility across all cards
    const allCards = document.querySelectorAll('.layout-card');
    allCards.forEach((cardEl) => {
      const cardCategory = cardEl.getAttribute('data-card');
      const isDetailCard = cardEl.classList.contains('detail-card');

      if (activeFilter === 'all') {
        if (isDetailCard) {
          cardEl.style.display = 'none';
        } else {
          cardEl.style.display = 'flex';
        }
      } else {
        if (cardCategory === activeFilter) {
          cardEl.style.display = 'flex';
        } else {
          cardEl.style.display = 'none';
        }
      }
    });
  }

  _renderCards(state) {
    const layout = state.layout || {};
    for (const [cardName, cardEl] of Object.entries(this.cardMap)) {
      if (!cardEl) continue;
      const size = (layout[cardName] || 'small').toLowerCase();

      // Update badge text
      const badge = cardEl.querySelector('.status-capsule');
      if (badge) {
        badge.textContent = size.toUpperCase();
        if (size === 'nightstand') {
          badge.className = 'status-capsule amber';
        } else {
          badge.className = 'status-capsule';
        }
      }

      // Update segmented button selection
      const buttons = cardEl.querySelectorAll('.segment-btn');
      buttons.forEach((btn) => {
        const btnId = btn.id || '';
        const isSelected = btnId.endsWith(`-${size}`);
        btn.classList.toggle('active', isSelected);
      });
    }

    if (this.cardClock) {
      this.cardClock.classList.toggle('nightstand-active', state.layout && state.layout.clock === 'nightstand');
    }

    // Update All Cards collective controller badge and buttons
    if (this.allCardsStatusBadge) {
      const clockSize = (layout.clock || 'small').toLowerCase();
      const habitsSize = (layout.habits || 'small').toLowerCase();
      const calSize = (layout.calendar || 'small').toLowerCase();
      const tasksSize = (layout.tasks || 'small').toLowerCase();

      const allMatch =
        clockSize === habitsSize &&
        habitsSize === calSize &&
        calSize === tasksSize &&
        (clockSize === 'small' || clockSize === 'medium' || clockSize === 'fullscreen');

      if (allMatch) {
        this.allCardsStatusBadge.textContent = clockSize.toUpperCase();
        this.allCardsStatusBadge.className = 'status-capsule';
        if (this.allCardsButtons) {
          Object.entries(this.allCardsButtons).forEach(([btnSize, btn]) => {
            if (btn) btn.classList.toggle('active', btnSize === clockSize);
          });
        }
      } else {
        this.allCardsStatusBadge.textContent = 'MIXED';
        this.allCardsStatusBadge.className = 'status-capsule mixed';
        if (this.allCardsButtons) {
          Object.values(this.allCardsButtons).forEach((btn) => {
            if (btn) btn.classList.remove('active');
          });
        }
      }
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

  _renderDisplay(state) {
    const display = state.display || {};
    const rawBrightness = typeof display.brightness === 'number' ? display.brightness : 1.0;
    const pct = Math.round(Math.max(0.05, Math.min(1.0, rawBrightness)) * 100);

    if (this.brightnessValueBadge) {
      this.brightnessValueBadge.textContent = `${pct}%`;
    }

    if (this.brightnessSlider) {
      // Avoid fighting the user's thumb while they are actively dragging.
      if (document.activeElement !== this.brightnessSlider) {
        this.brightnessSlider.value = String(pct);
      }
      this._paintBrightnessSlider(pct);
    }
  }

  _renderTasks(state) {
    if (!this.tasksList) return;

    const tasks = state.tasks || [];
    const completedCount = tasks.filter((t) => t.is_completed || t.completed).length;

    if (this.tasksCounter) {
      this.tasksCounter.textContent = `${completedCount}/${tasks.length}`;
    }

    if (tasks.length === 0) {
      this.tasksList.innerHTML = '<div class="tasks-empty-msg">No tasks pending. Tap Add to create one.</div>';
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
        <div class="task-item-row ${isCompleted ? 'completed' : ''}" data-task-id="${task.id}" role="listitem">
          <button class="task-checkbox ${isCompleted ? 'checked' : ''}" onclick="window.wyrmRemote.toggleTask('${task.id}')" title="Toggle completion" aria-label="Toggle task completion">
            ${checkIcon}
          </button>
          <span class="task-title-text" style="font-size: ${cardFontSize}px" onclick="window.wyrmRemote.toggleTask('${task.id}')">${this._escapeHtml(task.title || task.text || '')}</span>
          ${priorityBadge}
          <button class="task-delete-btn" onclick="window.wyrmRemote.deleteTask('${task.id}')" title="Delete task" aria-label="Delete task">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      `;
    }).join('');
  }

  _renderCalendar(state) {
    const cal = state.calendar || {};
    const settings = state.settings || {};

    if (this.startWeekToggle) {
      const startMon = !!settings.startWeekOnMonday;
      this.startWeekToggle.classList.toggle('active', startMon);
      this.startWeekToggle.setAttribute('aria-checked', startMon ? 'true' : 'false');
    }

    if (this.dayOfYearBadge) {
      this.dayOfYearBadge.textContent = `DAY ${cal.dayOfYear || 1}/${cal.daysInYear || 365}`;
    }
    if (this.yearProgressFill && this.yearProgressLabel) {
      const yearPct = ((cal.yearProgress || 0) * 100).toFixed(1);
      this.yearProgressFill.style.width = `${yearPct}%`;
      this.yearProgressLabel.textContent = `${new Date().getFullYear()} Progress: ${yearPct}%`;
    }
    if (this.quarterProgressFill && this.quarterProgressLabel) {
      const qPct = ((cal.quarterProgress || 0) * 100).toFixed(1);
      this.quarterProgressFill.style.width = `${qPct}%`;
      this.quarterProgressLabel.textContent = `Q${cal.currentQuarter || 1} Progress: ${qPct}%`;
    }

    this._renderWebCalendarWidget(state);
    this._renderMilestones(state);
  }

  _renderWebCalendarWidget(state) {
    if (!this.webCalDays || !this.webCalWeekdays || !this.webCalMonthYear) return;

    const cal = state.calendar || {};
    const settings = state.settings || {};
    const startMon = !!settings.startWeekOnMonday;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    const viewYear = this.webCalViewDate.getFullYear();
    const viewMonth = this.webCalViewDate.getMonth();

    this.webCalMonthYear.textContent = `${monthNames[viewMonth]} ${viewYear}`;

    const weekdaysSunday = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    const weekdaysMonday = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const headers = startMon ? weekdaysMonday : weekdaysSunday;
    this.webCalWeekdays.innerHTML = headers.map(h => `<div class="web-cal-weekday-cell">${h}</div>`).join('');

    const firstDay = new Date(viewYear, viewMonth, 1);
    const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();

    let offset = firstDay.getDay();
    if (startMon) {
      offset = (offset + 6) % 7;
    }

    const today = new Date();
    const isThisMonth = today.getFullYear() === viewYear && today.getMonth() === viewMonth;
    const todayDate = today.getDate();

    const selectedYear = this.webCalSelectedDate.getFullYear();
    const selectedMonth = this.webCalSelectedDate.getMonth();
    const isSelectedMonth = selectedYear === viewYear && selectedMonth === viewMonth;
    const selectedDate = this.webCalSelectedDate.getDate();

    const isMarkerOnToday = isThisMonth && isSelectedMonth && selectedDate === todayDate;
    const webTodayBtn = document.getElementById('webCalTodayBtn');
    if (webTodayBtn) {
      webTodayBtn.style.display = isMarkerOnToday ? 'none' : '';
    }

    const milestones = cal.milestones || [];
    const milestoneDays = new Set(
      milestones
        .map(m => {
          const raw = m.target_date || m.targetDate || m.date;
          if (typeof raw === 'string' && raw.includes('-')) {
            const datePart = raw.split('T')[0];
            const parts = datePart.split('-');
            if (parts.length === 3) {
              return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
            }
          } else if (typeof raw === 'string' && raw.includes('/')) {
            const parts = raw.split('/');
            if (parts.length === 3) {
              return new Date(parseInt(parts[2], 10), parseInt(parts[1], 10) - 1, parseInt(parts[0], 10));
            }
          }
          return new Date(raw);
        })
        .filter(d => d && !isNaN(d.getTime()) && d.getFullYear() === viewYear && d.getMonth() === viewMonth)
        .map(d => d.getDate())
    );

    let html = '';
    for (let i = 0; i < offset; i++) {
      html += '<div class="web-cal-day-cell empty"></div>';
    }

    for (let day = 1; day <= daysInMonth; day++) {
      const isToday = isThisMonth && day === todayDate;
      const isSelected = isSelectedMonth && day === selectedDate;
      const hasMilestone = milestoneDays.has(day);

      const classes = ['web-cal-day-cell'];
      if (isToday) classes.push('today');
      if (isSelected) classes.push('selected');
      if (hasMilestone) classes.push('has-milestone');

      html += `<div class="${classes.join(' ')}" onclick="window.wyrmRemote.selectWebDate(${viewYear}, ${viewMonth}, ${day})" role="button" tabindex="0">${day}</div>`;
    }

    this.webCalDays.innerHTML = html;

    if (this.webCalSelectedStatus) {
      const sel = this.webCalSelectedDate;
      const todayMid = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      const selMid = new Date(sel.getFullYear(), sel.getMonth(), sel.getDate());
      const diffDays = Math.round((selMid - todayMid) / (1000 * 60 * 60 * 24));

      let relativeText = 'Today';
      if (diffDays === 1) relativeText = '+1 day from today';
      else if (diffDays === -1) relativeText = 'Yesterday';
      else if (diffDays > 0) relativeText = `+${diffDays} days from now`;
      else if (diffDays < 0) relativeText = `${Math.abs(diffDays)} days ago`;

      const day = String(sel.getDate()).padStart(2, '0');
      const month = String(sel.getMonth() + 1).padStart(2, '0');
      const year = sel.getFullYear();
      const dateFormatted = `${day}/${month}/${year}`;
      this.webCalSelectedStatus.textContent = `${dateFormatted} • ${relativeText}`;
    }
  }

  _renderMilestones(state) {
    if (!this.milestonesList) return;

    const milestones = (state.calendar && state.calendar.milestones) || [];

    if (this.milestonesCounter) {
      this.milestonesCounter.textContent = `${milestones.length}`;
    }

    if (milestones.length === 0) {
      this.milestonesList.innerHTML = '<div class="tasks-empty-msg">No milestones yet. Add one above!</div>';
      return;
    }

    const today = new Date();
    const todayMid = new Date(today.getFullYear(), today.getMonth(), today.getDate());

    this.milestonesList.innerHTML = milestones.map((m) => {
      let target;
      const rawDate = m.target_date || m.targetDate || m.date;
      if (typeof rawDate === 'string' && rawDate.includes('-')) {
        const datePart = rawDate.split('T')[0];
        const parts = datePart.split('-');
        if (parts.length === 3) {
          target = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        }
      } else if (typeof rawDate === 'string' && rawDate.includes('/')) {
        const parts = rawDate.split('/');
        if (parts.length === 3) {
          target = new Date(parseInt(parts[2], 10), parseInt(parts[1], 10) - 1, parseInt(parts[0], 10));
        }
      }
      if (!target || isNaN(target.getTime())) {
        target = new Date(rawDate || Date.now());
      }
      const targetMid = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const diffDays = Math.round((targetMid - todayMid) / (1000 * 60 * 60 * 24));

      let badge = `${diffDays}d`;
      if (diffDays === 0) badge = 'TODAY';
      else if (diffDays === 1) badge = 'TOMORROW';
      else if (diffDays > 0) badge = `IN ${diffDays}d`;
      else badge = `${Math.abs(diffDays)}d AGO`;

      const isPinned = !!(m.is_pinned || m.pinned);
      const pinSvg = isPinned
        ? '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>'
        : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>';
      
      const day = String(target.getDate()).padStart(2, '0');
      const month = String(target.getMonth() + 1).padStart(2, '0');
      const year = target.getFullYear();
      const dateStr = `${day}/${month}/${year}`;

      return `
        <div class="milestone-item-row" data-milestone-id="${m.id}" role="listitem">
          <button class="milestone-pin-btn ${isPinned ? 'pinned' : ''}" onclick="window.wyrmRemote.togglePinMilestone('${m.id}')" title="Pin to countdown" aria-label="Pin milestone">
            ${pinSvg}
          </button>
          <div class="milestone-title-group">
            <span class="milestone-title">${this._escapeHtml(m.title || m.text || '')}</span>
            <span class="milestone-date-subtext">${dateStr}</span>
          </div>
          <span class="milestone-days-capsule">${badge}</span>
          <button class="task-delete-btn" onclick="window.wyrmRemote.deleteMilestone('${m.id}')" title="Delete milestone" aria-label="Delete milestone">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      `;
    }).join('');
  }

  _renderHabits(state) {
    if (!this.habitsList) return;

    const habits = state.habits || [];
    const todayStr = new Date().toISOString().split('T')[0];

    const completedToday = habits.filter((h) => {
      const completions = h.completions || {};
      const count = completions[todayStr] || 0;
      const target = h.target_value || 1;
      return count >= target;
    }).length;

    if (this.habitsCounter) {
      this.habitsCounter.textContent = `${completedToday}/${habits.length}`;
    }

    if (habits.length === 0) {
      this.habitsList.innerHTML = '<div class="tasks-empty-msg">No habits tracked yet. Add one above!</div>';
      return;
    }

    this.habitsList.innerHTML = habits.map((habit) => {
      const completions = habit.completions || {};
      const count = completions[todayStr] || 0;
      const target = habit.target_value || 1;
      const isDone = count >= target;
      const isNumeric = (habit.type || '').toLowerCase() === 'numeric';

      return `
        <div class="habit-item-row" data-habit-id="${habit.id}" role="listitem">
          <div class="habit-title-group">
            <span class="habit-glyph">${this._resolveGlyphEmoji(habit.icon_name || habit.iconName)}</span>
            <span class="habit-title">${this._escapeHtml(habit.title || '')}</span>
          </div>
          <div class="habit-action-group">
            ${isNumeric ? `
              <div class="habit-stepper-control" role="group" aria-label="Step habit count">
                <button class="stepper-btn" onclick="window.wyrmRemote.stepHabit('${habit.id}', -1)" title="Decrement" aria-label="Decrement count">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                </button>
                <span class="habit-stepper-val">${count}/${target} ${habit.unit ? this._escapeHtml(habit.unit) : ''}</span>
                <button class="stepper-btn" onclick="window.wyrmRemote.stepHabit('${habit.id}', 1)" title="Increment" aria-label="Increment count">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                </button>
              </div>
            ` : `
              <button class="habit-toggle-btn ${isDone ? 'done' : ''}" onclick="window.wyrmRemote.toggleHabit('${habit.id}')" aria-label="Toggle habit completion">
                ${isDone ? `
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                  <span>Done</span>
                ` : `
                  <span>Today</span>
                `}
              </button>
            `}
            <button class="task-delete-btn" onclick="window.wyrmRemote.deleteHabit('${habit.id}')" title="Delete habit" aria-label="Delete habit">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
          </div>
        </div>
      `;
    }).join('');
  }

  _resolveGlyphEmoji(iconName) {
    const glyphMap = {
      bolt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>',
      water_drop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>',
      fitness_center: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 5v14M18 5v14M2 9v6M22 9v6M6 12h12"></path></svg>',
      menu_book: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg>',
      directions_run: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="2"></circle><path d="M10 22l3-7 3-3-2-4-4 2"></path><path d="M6 14l4-2 3 3"></path></svg>',
      bedtime: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>',
      wb_sunny: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line></svg>',
      code: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>',
      local_cafe: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg>',
      check_circle: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="16 9 12 15 8 11"></polyline></svg>',
      favorite: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>',
    };
    return glyphMap[iconName] || glyphMap.bolt;
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

  // Global interface for inline triggers & cross-window controller
  window.wyrmRemote = {
    setCardSize: (card, size) => renderer.setCardSize(card, size),
    setAllCardsSize: (size) => renderer.setAllCardsSize(size),
    toggleTimeFormat: () => renderer.toggleTimeFormat(),
    incrementFontSize: () => renderer.incrementFontSize(),
    decrementFontSize: () => renderer.decrementFontSize(),
    previewBrightness: (value) => renderer.previewBrightness(value),
    setBrightness: (value) => renderer.setBrightness(value),
    setCardFilter: (filter) => renderer.setCardFilter(filter),
    toggleSideNav: () => renderer.toggleSideNav(),
    cycleTheme: () => renderer.cycleTheme(),
    addTask: () => renderer.addTask(),
    toggleTask: (id) => renderer.toggleTask(id),
    deleteTask: (id) => renderer.deleteTask(id),
    toggleStartWeekOnMonday: () => renderer.toggleStartWeekOnMonday(),
    prevWebMonth: () => renderer.prevWebMonth(),
    nextWebMonth: () => renderer.nextWebMonth(),
    todayWebMonth: () => renderer.todayWebMonth(),
    promptTravelDate: () => renderer.promptTravelDate(),
    travelWebDate: (dateStr) => renderer.travelWebDate(dateStr),
    selectWebDate: (year, month, day) => renderer.selectWebDate(year, month, day),
    addMilestone: () => renderer.addMilestone(),
    createMilestone: (title, date, isPinned) => renderer.wsManager.createMilestone(title, date, isPinned),
    deleteMilestone: (id) => renderer.deleteMilestone(id),
    togglePinMilestone: (id) => renderer.togglePinMilestone(id),
    pickMilestoneDate: () => renderer.pickMilestoneDate(),
    onMilestonePickerChange: (val) => renderer.onMilestonePickerChange(val),
    onHabitTypeChange: (val) => renderer.onHabitTypeChange(val),
    selectHabitGlyph: (glyph) => renderer.selectHabitGlyph(glyph),
    addHabit: () => renderer.addHabit(),
    toggleHabit: (id) => renderer.toggleHabit(id),
    stepHabit: (id, delta) => renderer.stepHabit(id, delta),
    deleteHabit: (id) => renderer.deleteHabit(id),
    scrollToCard: (card) => renderer.scrollToCard(card),
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
        display: initialSnapshot.display || {},
        tasks: initialSnapshot.tasks || [],
        habits: initialSnapshot.habits || [],
        calendar: initialSnapshot.calendar || {},
      });
    }
  } catch (_) {}

  // Connect live WebSocket channel
  wsManager.connect();
});
