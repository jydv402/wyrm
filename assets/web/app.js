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
        startWeekOnMonday: false,
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

  createMilestone(title, targetDate, isPinned = false) {
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

    this.webCalViewDate = new Date();
    this.webCalSelectedDate = new Date();

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
      if (cardCategory) {
        this.scrollToCard(cardCategory, cardEl);
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
      // Trigger reflow to restart CSS animation if clicked repeatedly
      void target.offsetWidth;
      target.classList.add('card-tapped');
      setTimeout(() => {
        target.classList.remove('card-tapped');
      }, 350);
    }
  }

  setCardFilter(filterName) {
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

  prevWebMonth() {
    this.webCalViewDate.setMonth(this.webCalViewDate.getMonth() - 1);
    this._renderWebCalendarWidget(this.store.getState());
  }

  nextWebMonth() {
    this.webCalViewDate.setMonth(this.webCalViewDate.getMonth() + 1);
    this._renderWebCalendarWidget(this.store.getState());
  }

  todayWebMonth() {
    this.webCalViewDate = new Date();
    this.webCalSelectedDate = new Date();
    this._renderWebCalendarWidget(this.store.getState());
  }

  promptTravelDate() {
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
    this.webCalSelectedDate = new Date(year, month, day);
    this._renderWebCalendarWidget(this.store.getState());
  }

  addMilestone() {
    if (!this.milestoneTitleInput) return;
    const title = this.milestoneTitleInput.value.trim();
    if (!title) return;
    const dateValue = this.milestoneDateInput && this.milestoneDateInput.value
        ? this.milestoneDateInput.value
        : new Date().toISOString().split('T')[0];
    const isPinned = this.milestonePinCheckbox ? this.milestonePinCheckbox.checked : false;

    this.wsManager.createMilestone(title, dateValue, isPinned);
    this.milestoneTitleInput.value = '';
    if (this.milestonePinCheckbox) this.milestonePinCheckbox.checked = false;
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
    this.selectedHabitGlyph = glyph || 'bolt';
    const chips = document.querySelectorAll('#habitGlyphPicker .glyph-chip');
    chips.forEach((c) => {
      if (c.getAttribute('data-glyph') === this.selectedHabitGlyph) {
        c.classList.add('selected');
      } else {
        c.classList.remove('selected');
      }
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
    this._renderTasks(state);
    this._renderCalendar(state);
    this._renderHabits(state);
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

  _renderCalendar(state) {
    const cal = state.calendar || {};
    const settings = state.settings || {};

    if (this.startWeekToggle) {
      this.startWeekToggle.classList.toggle('active', !!settings.startWeekOnMonday);
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
        .map(m => new Date(m.target_date || m.targetDate || m.date))
        .filter(d => !isNaN(d.getTime()) && d.getFullYear() === viewYear && d.getMonth() === viewMonth)
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

      html += `<div class="${classes.join(' ')}" onclick="window.wyrmRemote.selectWebDate(${viewYear}, ${viewMonth}, ${day})">${day}</div>`;
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

      const formatted = `${monthNames[sel.getMonth()]} ${sel.getDate()}, ${sel.getFullYear()}`;
      this.webCalSelectedStatus.textContent = `${formatted} • ${relativeText}`;
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
      const target = new Date(m.target_date || m.targetDate || m.date || Date.now());
      const targetMid = new Date(target.getFullYear(), target.getMonth(), target.getDate());
      const diffDays = Math.round((targetMid - todayMid) / (1000 * 60 * 60 * 24));

      let badge = `${diffDays}d`;
      if (diffDays === 0) badge = 'TODAY';
      else if (diffDays === 1) badge = 'TOMORROW';
      else if (diffDays > 0) badge = `IN ${diffDays}d`;
      else badge = `${Math.abs(diffDays)}d AGO`;

      const isPinned = !!(m.is_pinned || m.pinned);
      const pinIcon = isPinned ? '📌' : '📍';
      const dateStr = target.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });

      return `
        <div class="milestone-item-row" data-milestone-id="${m.id}">
          <button class="milestone-pin-btn ${isPinned ? 'pinned' : ''}" onclick="window.wyrmRemote.togglePinMilestone('${m.id}')" title="Pin to countdown">${pinIcon}</button>
          <div class="milestone-title-group">
            <span class="milestone-title">${this._escapeHtml(m.title || m.text || '')}</span>
            <span class="milestone-date-subtext">${dateStr}</span>
          </div>
          <span class="milestone-days-capsule">${badge}</span>
          <button class="task-delete-btn" onclick="window.wyrmRemote.deleteMilestone('${m.id}')" title="Delete milestone">×</button>
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
        <div class="habit-item-row" data-habit-id="${habit.id}">
          <div class="habit-title-group">
            <span class="habit-glyph">${this._resolveGlyphEmoji(habit.icon_name || habit.iconName)}</span>
            <span class="habit-title">${this._escapeHtml(habit.title || '')}</span>
          </div>
          <div class="habit-action-group">
            ${isNumeric ? `
              <div class="habit-stepper-control">
                <button class="stepper-control" onclick="window.wyrmRemote.stepHabit('${habit.id}', -1)" title="Decrement">−</button>
                <span class="habit-stepper-val">${count}/${target} ${habit.unit ? this._escapeHtml(habit.unit) : ''}</span>
                <button class="stepper-control" onclick="window.wyrmRemote.stepHabit('${habit.id}', 1)" title="Increment">+</button>
              </div>
            ` : `
              <button class="habit-toggle-btn ${isDone ? 'done' : ''}" onclick="window.wyrmRemote.toggleHabit('${habit.id}')">
                <span>${isDone ? '✓ Done' : '○ Today'}</span>
              </button>
            `}
            <button class="task-delete-btn" onclick="window.wyrmRemote.deleteHabit('${habit.id}')" title="Delete habit">×</button>
          </div>
        </div>
      `;
    }).join('');
  }

  _resolveGlyphEmoji(iconName) {
    const glyphMap = {
      bolt: '⚡',
      water_drop: '💧',
      fitness_center: '🏋️',
      menu_book: '📖',
      directions_run: '🏃',
      bedtime: '🌙',
      wb_sunny: '☀️',
      code: '💻',
      local_cafe: '☕',
      check_circle: '✅',
      favorite: '❤️',
    };
    return glyphMap[iconName] || '⚡';
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
    toggleStartWeekOnMonday: () => renderer.toggleStartWeekOnMonday(),
    prevWebMonth: () => renderer.prevWebMonth(),
    nextWebMonth: () => renderer.nextWebMonth(),
    todayWebMonth: () => renderer.todayWebMonth(),
    promptTravelDate: () => renderer.promptTravelDate(),
    travelWebDate: (dateStr) => renderer.travelWebDate(dateStr),
    selectWebDate: (year, month, day) => renderer.selectWebDate(year, month, day),
    addMilestone: () => renderer.addMilestone(),
    deleteMilestone: (id) => renderer.deleteMilestone(id),
    togglePinMilestone: (id) => renderer.togglePinMilestone(id),
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
        tasks: initialSnapshot.tasks || [],
        habits: initialSnapshot.habits || [],
        calendar: initialSnapshot.calendar || {},
      });
    }
  } catch (_) {}

  // Connect live WebSocket channel
  wsManager.connect();
});
