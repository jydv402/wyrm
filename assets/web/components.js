/**
 * WYRM DESK REMOTE - components
 *
 * Every piece of UI is a small component with a string template, so the whole
 * app runs from vue.global.prod.js with no build step. Load order:
 *   vue.global.prod.js → components.js → app.js
 *
 * Layers (each only uses the one above it):
 *   1. Primitives  ui-icon, ui-panel, ui-button, segmented-control, …
 *   2. Chrome      nav-rail, top-bar, connection-badge, nightstand-toggle
 *   3. Features    task-row, habit-card, month-grid, milestones-panel, …
 *   4. Views       view-deck, view-tasks, view-habits, view-calendar, view-settings
 *   5. Root        wyrm-app
 *
 * Components get state and actions through inject('wyrm'), see createWyrmActions().
 */
(function () {
  const { ref, computed, inject, onMounted, onUnmounted, nextTick } = Vue;

  const components = {};
  const directives = {};

  /* ========================================================================
     1. PRIMITIVES
     ======================================================================== */

  const ICONS = {
    grid: '<rect x="3.5" y="3.5" width="7" height="7" rx="2.2"/><rect x="13.5" y="3.5" width="7" height="7" rx="2.2"/><rect x="3.5" y="13.5" width="7" height="7" rx="2.2"/><rect x="13.5" y="13.5" width="7" height="7" rx="2.2"/>',
    tasks: '<circle cx="12" cy="12" r="9"/><path d="m8.4 12.4 2.5 2.5 4.7-5.2"/>',
    pulse: '<path d="M3 12h4l2.5-6.5L14 18l2.5-6H21"/>',
    calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="3.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    moon: '<path d="M20 14.2A8.2 8.2 0 0 1 9.8 4 8.2 8.2 0 1 0 20 14.2z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    x: '<path d="m6.5 6.5 11 11M17.5 6.5l-11 11"/>',
    check: '<path d="m5 12.5 4.6 4.6L19 7.6"/>',
    'chevron-left': '<path d="m14.5 6-6 6 6 6"/>',
    'chevron-right': '<path d="m9.5 6 6 6-6 6"/>',
    'chevron-down': '<path d="m6 9.5 6 6 6-6"/>',
    star: '<path d="m12 3.5 2.6 5.4 5.9.8-4.3 4.1 1 5.9L12 16.9l-5.2 2.8 1-5.9-4.3-4.1 5.9-.8z"/>',
    locate: '<circle cx="12" cy="12" r="3"/><path d="M12 3v3.5M12 17.5V21M3 12h3.5M17.5 12H21"/>',
    leaf: '<path d="M5 19C5 10.5 10.5 5 20 5c0 9.5-5.5 14-13.5 14"/><path d="M5 19 13 11"/>',
    sprout: '<path d="M12 20v-8"/><path d="M12 12c0-3.5-2.5-6-6.5-6 0 3.5 2.5 6 6.5 6z"/><path d="M12 14c0-3 2.2-5 5.5-5 0 3-2.2 5-5.5 5z"/>',
    checkbox: '<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><path d="m8.2 12.3 2.7 2.7 5-5.5"/>',
    gear: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
    wifi: '<path d="M2.5 9a15 15 0 0 1 19 0"/><path d="M5.8 12.6a10.5 10.5 0 0 1 12.4 0"/><path d="M9 16.1a5.5 5.5 0 0 1 6 0"/><path d="M12 19.5h.01"/>',
    qr: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><path d="M7 7h.01M18 7h.01M7 18h.01M14 14h3v3h-3zM17 17v4M14 21h7M21 14v3"/>',
    copy: '<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    database: '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>',
    compass: '<circle cx="12" cy="12" r="9"/><polygon points="16.2 7.8 14.1 14.1 7.8 16.2 9.9 9.9 16.2 7.8"/>',
    bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    share: '<path d="M8 7h12m0 0-4-4m4 4-4 4"/><path d="M16 17H4m0 0 4 4m-4-4 4-4"/>',
  };

  components.UiIcon = {
    name: 'UiIcon',
    props: {
      name: { type: String, required: true },
      size: { type: [Number, String], default: 20 },
      stroke: { type: Number, default: 1.8 },
    },
    setup(props) {
      return { paths: computed(() => ICONS[props.name] || '') };
    },
    template: `
      <svg class="icon" :width="size" :height="size" viewBox="0 0 24 24" fill="none"
           stroke="currentColor" :stroke-width="stroke" stroke-linecap="round" stroke-linejoin="round"
           aria-hidden="true" focusable="false" v-html="paths"></svg>`,
  };

  /** The base surface: a chrome-edged, glossy card. */
  components.UiPanel = {
    name: 'UiPanel',
    props: { flush: Boolean },
    template: `<section class="panel" :class="{ 'panel--flush': flush }"><slot /></section>`,
  };

  components.PanelHead = {
    name: 'PanelHead',
    props: { title: { type: String, required: true }, subtitle: String, icon: String },
    template: `
      <header class="panel-head">
        <ui-icon v-if="icon" :name="icon" :size="24" class="panel-head__icon" />
        <div class="panel-head__text">
          <h2 class="panel-head__title">{{ title }}</h2>
          <p v-if="subtitle" class="panel-head__sub">{{ subtitle }}</p>
        </div>
        <div v-if="$slots.default" class="panel-head__actions"><slot /></div>
      </header>`,
  };

  components.UiButton = {
    name: 'UiButton',
    props: {
      variant: { type: String, default: 'default' }, // default | primary | ghost | danger
      size: { type: String, default: 'md' },         // md | sm | icon
      icon: String,
      active: Boolean,
    },
    template: `
      <button type="button" class="btn" :class="['btn--' + variant, 'btn--' + size, { 'is-active': active }]">
        <ui-icon v-if="icon" :name="icon" :size="size === 'md' ? 19 : 18" />
        <span v-if="$slots.default" class="btn__label"><slot /></span>
      </button>`,
  };

  components.SegmentedControl = {
    name: 'SegmentedControl',
    props: {
      modelValue: { default: null },
      options: { type: Array, required: true }, // [{ value, label, tone? }]
      ariaLabel: String,
    },
    emits: ['update:modelValue'],
    setup(props) {
      const index = computed(() => props.options.findIndex((o) => o.value === props.modelValue));
      const selected = computed(() => props.options[index.value] || null);
      return { index, selected };
    },
    template: `
      <div class="seg" role="radiogroup" :aria-label="ariaLabel"
           :class="{ 'seg--empty': index < 0 }" :data-tone="selected && selected.tone"
           :style="{ '--n': options.length, '--i': Math.max(index, 0) }">
        <span class="seg__thumb" aria-hidden="true"></span>
        <button v-for="o in options" :key="String(o.value)" type="button" role="radio"
                class="seg__opt" :class="{ 'is-on': o.value === modelValue }"
                :aria-checked="o.value === modelValue"
                @click="$emit('update:modelValue', o.value)">{{ o.label }}</button>
      </div>`,
  };

  components.StepperControl = {
    name: 'StepperControl',
    props: { label: { type: String, required: true } },
    emits: ['dec', 'inc'],
    template: `
      <div class="stepper">
        <ui-button size="icon" icon="minus" aria-label="Decrease" @click="$emit('dec')" />
        <output class="stepper__value">{{ label }}</output>
        <ui-button size="icon" icon="plus" aria-label="Increase" @click="$emit('inc')" />
      </div>`,
  };

  components.UiInput = {
    name: 'UiInput',
    props: {
      modelValue: { type: [String, Number], default: '' },
      type: { type: String, default: 'text' },
      placeholder: String,
    },
    emits: ['update:modelValue', 'enter'],
    template: `
      <input class="field" :type="type" :value="modelValue" :placeholder="placeholder"
             :aria-label="placeholder" autocomplete="off"
             @input="$emit('update:modelValue', $event.target.value)"
             @keydown.enter="$emit('enter')">`,
  };

  components.DateField = {
    name: 'DateField',
    props: { modelValue: { type: String, default: '' } },
    emits: ['update:modelValue'],
    template: `
      <input class="field field--date" type="date" :value="modelValue"
             @input="$emit('update:modelValue', $event.target.value)">`,
  };

  components.UiSlider = {
    name: 'UiSlider',
    props: {
      modelValue: { type: Number, required: true },
      min: { type: Number, default: 0 },
      max: { type: Number, default: 1 },
      step: { type: Number, default: 0.01 },
    },
    emits: ['update:modelValue'],
    setup(props) {
      const fill = computed(() => {
        const val = typeof props.modelValue === 'number' ? props.modelValue : 1.0;
        return Math.max(0, Math.min(100, ((val - props.min) / (props.max - props.min)) * 100));
      });
      return { fill };
    },
    template: `
      <input class="slider" type="range" :min="min" :max="max" :step="step" :value="modelValue"
             :style="{ '--fill': fill + '%' }"
             aria-label="Display brightness"
             @input="$emit('update:modelValue', parseFloat($event.target.value))"
             @change="$emit('update:modelValue', parseFloat($event.target.value))">`,
  };

  components.ProgressMeter = {
    name: 'ProgressMeter',
    props: { label: { type: String, required: true }, percent: { type: Number, required: true } },
    template: `
      <div class="meter">
        <span class="meter__label">{{ label }}</span>
        <span class="meter__value">{{ percent }}<small>%</small></span>
        <div class="meter__track" role="progressbar" aria-valuemin="0" aria-valuemax="100"
             :aria-valuenow="percent" :aria-label="label">
          <div class="meter__fill" :style="{ width: percent + '%' }"></div>
        </div>
      </div>`,
  };

  components.StatusPill = {
    name: 'StatusPill',
    props: { tone: { type: String, default: 'neutral' } }, // high | medium | low | accent | neutral
    template: `<span class="pill" :class="'pill--' + tone"><slot /></span>`,
  };

  components.EmptyState = {
    name: 'EmptyState',
    props: { icon: String, title: { type: String, required: true }, hint: String },
    template: `
      <div class="empty">
        <span class="empty__icon glass"><ui-icon v-if="icon" :name="icon" :size="24" /></span>
        <p class="empty__title">{{ title }}</p>
        <p v-if="hint" class="empty__hint">{{ hint }}</p>
      </div>`,
  };

  components.SettingRow = {
    name: 'SettingRow',
    props: { label: { type: String, required: true }, hint: String },
    template: `
      <div class="setting">
        <div class="setting__text">
          <div class="setting__label">{{ label }}</div>
          <div v-if="hint" class="setting__hint">{{ hint }}</div>
        </div>
        <div class="setting__control"><slot /></div>
      </div>`,
  };

  /* ========================================================================
     2. CHROME
     ======================================================================== */

  const DESTINATIONS = [
    { id: 'deck', label: 'Deck', icon: 'grid', tone: 'slate', view: 'view-deck' },
    { id: 'tasks', label: 'Tasks', icon: 'checkbox', tone: 'rust', view: 'view-tasks' },
    { id: 'habits', label: 'Habits', icon: 'leaf', tone: 'teal', view: 'view-habits' },
    { id: 'cal', label: 'Calendar', icon: 'calendar', tone: 'gold', view: 'view-calendar' },
    { id: 'sys', label: 'Settings', icon: 'gear', tone: 'slate', view: 'view-settings' },
  ];

  components.BackdropScene = {
    name: 'BackdropScene',
    template: `<div class="backdrop" aria-hidden="true"></div>`,
  };

  components.NavItem = {
    name: 'NavItem',
    props: { icon: String, label: String, tone: String, active: Boolean, badge: { type: Number, default: 0 } },
    emits: ['select'],
    template: `
      <button type="button" class="nav-item" :class="{ 'is-active': active }" :data-tone="tone"
              :aria-current="active ? 'page' : null" @click="$emit('select')">
        <ui-icon :name="icon" :size="22" :stroke="active ? 2 : 1.7" />
        <span class="nav-item__label">{{ label }}</span>
        <span v-if="badge > 0" class="nav-item__badge">{{ badge }}</span>
      </button>`,
  };

  /** One component, two layouts: a sidebar on desktop, a floating bottom bar on mobile (CSS only). */
  components.NavRail = {
    name: 'NavRail',
    setup() {
      const wyrm = inject('wyrm');
      const index = computed(() => Math.max(0, DESTINATIONS.findIndex((d) => d.id === wyrm.state.currentChannel)));
      const openTasks = computed(() => wyrm.state.tasks.filter((t) => !t.is_completed).length);
      return { wyrm, destinations: DESTINATIONS, index, openTasks };
    },
    template: `
      <ui-panel class="nav-rail">
        <div class="nav-brand">
          <img class="nav-brand__mark" src="/assets/icons/icon_flat.png" alt="">
          <div>
            <div class="nav-brand__name">WYRM<span class="nav-brand__dot">.</span></div>
            <div class="nav-brand__sub">Desk Remote</div>
          </div>
        </div>
        <nav class="nav-items" aria-label="Destinations" :style="{ '--i': index, '--n': destinations.length }">
          <span class="nav-thumb" aria-hidden="true"></span>
          <nav-item v-for="d in destinations" :key="d.id" :icon="d.icon" :label="d.label" :tone="d.tone"
                    :active="d.id === wyrm.state.currentChannel"
                    :badge="d.id === 'tasks' ? openTasks : 0"
                    @select="wyrm.setChannel(d.id)" />
        </nav>
      </ui-panel>`,
  };

  components.ConnectionBadge = {
    name: 'ConnectionBadge',
    setup() {
      const wyrm = inject('wyrm');
      const host = window.location.host || '127.0.0.1:8080';
      return { wyrm, host };
    },
    template: `
      <div class="conn" :class="{ 'is-live': wyrm.state.isConnected }" role="status"
           :aria-label="wyrm.state.isConnected ? 'Connected to ' + host : 'Connecting'">
        <ui-icon name="wifi" :size="20" :stroke="2" />
        <span class="conn__text">{{ wyrm.state.isConnected ? host : 'Connecting' }}</span>
        <span v-if="wyrm.state.isConnected && wyrm.state.latencyMs !== null" class="conn__ms">{{ wyrm.state.latencyMs }} ms</span>
      </div>`,
  };

  components.NightstandToggle = {
    name: 'NightstandToggle',
    setup() {
      const wyrm = inject('wyrm');
      return { wyrm, on: computed(() => wyrm.state.layout.clock === 'nightstand') };
    },
    template: `
      <ui-button icon="moon" :active="on" :aria-pressed="on" aria-label="Nightstand mode"
                    title="Nightstand mode: amber clock for the dark" @click="wyrm.toggleNightstand()">
        <span class="hide-sm">Nightstand</span>
      </ui-button>`,
  };

  components.NetworkModalButton = {
    name: 'NetworkModalButton',
    setup() {
      const wyrm = inject('wyrm');
      const on = computed(() => !!wyrm.state.networkModalOpen);
      return { wyrm, on };
    },
    template: `
      <ui-button size="icon" icon="qr" :active="on" :aria-pressed="on"
                 aria-label="Toggle QR Code Modal"
                 title="Toggle QR Code Modal"
                 @click="wyrm.toggleNetworkModal()" />`,
  };

  /** Shared modal behavior: Escape closes, and the page behind stops scrolling. */
  function useModal(emit) {
    const root = document.documentElement;
    const prevOverflow = root.style.overflow;
    function onKeydown(e) {
      if (e.key === 'Escape') emit('close');
    }
    onMounted(() => {
      root.style.overflow = 'hidden';
      window.addEventListener('keydown', onKeydown);
    });
    onUnmounted(() => {
      root.style.overflow = prevOverflow;
      window.removeEventListener('keydown', onKeydown);
    });
  }

  components.NetworkModal = {
    name: 'NetworkModal',
    emits: ['close'],
    setup(props, { emit }) {
      const wyrm = inject('wyrm');
      const copied = ref(false);
      const qrSvg = ref('');
      let copyTimer = null;

      // The modal is teleported out of .app, so it carries its own tone: the one of the page it was opened from.
      const tone = computed(() => {
        const d = DESTINATIONS.find((x) => x.id === wyrm.state.currentChannel);
        return (d && d.tone) || 'slate';
      });

      const connectionUrl = computed(() => {
        const loc = typeof window !== 'undefined' ? window.location : null;
        const origin = (loc && loc.origin && loc.origin !== 'null') ? loc.origin : '';
        const isLoopback = !origin || origin.includes('localhost') || origin.includes('127.0.0.1');

        if (origin && !isLoopback) {
          return origin;
        }
        if (wyrm.state.serverUrl && !wyrm.state.serverUrl.includes('127.0.0.1')) {
          return wyrm.state.serverUrl;
        }
        return origin || wyrm.state.serverUrl || 'http://127.0.0.1:8080';
      });

      const qrSrc = computed(() => '/api/qr?data=' + encodeURIComponent(connectionUrl.value));

      async function fetchQrSvg(url) {
        try {
          const res = await fetch('/api/qr?data=' + encodeURIComponent(url));
          if (res.ok) {
            const text = await res.text();
            if (text && text.includes('<svg')) {
              qrSvg.value = text;
            }
          }
        } catch (_) { }
      }

      async function copyUrl() {
        try {
          if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(connectionUrl.value);
            copied.value = true;
            clearTimeout(copyTimer);
            copyTimer = setTimeout(() => {
              copied.value = false;
            }, 2000);
          }
        } catch (_) { }
      }

      useModal(emit);
      onMounted(() => fetchQrSvg(connectionUrl.value));
      onUnmounted(() => clearTimeout(copyTimer));

      return { wyrm, tone, copied, connectionUrl, qrSrc, qrSvg, copyUrl };
    },
    template: `
      <teleport to="body">
        <div class="modal-backdrop" @click.self="$emit('close')">
          <ui-panel class="modal-card modal-card--network" :data-tone="tone" role="dialog" aria-modal="true" aria-label="Web remote">
            <panel-head title="Web remote" subtitle="Open it on your phone or laptop" icon="wifi">
              <ui-button size="icon" icon="x" aria-label="Close" @click="$emit('close')" />
            </panel-head>

            <div class="net-qr">
              <div class="net-qr__frame">
                <div v-if="qrSvg" class="net-qr__svg" v-html="qrSvg"></div>
                <img v-else :src="qrSrc" alt="QR code for the web remote" class="net-qr__img" width="200" height="200">
              </div>
              <p class="net-qr__hint">Point your phone camera at the code to open Wyrm Desk in your browser.</p>
            </div>

            <div class="net-address">
              <div class="net-address__text">
                <span class="net-address__label">Address</span>
                <code class="net-address__url">{{ connectionUrl }}</code>
              </div>
              <ui-button size="sm" :variant="copied ? 'primary' : 'default'" :icon="copied ? 'check' : 'copy'" @click="copyUrl">
                {{ copied ? 'Copied' : 'Copy' }}
              </ui-button>
            </div>
          </ui-panel>
        </div>
      </teleport>`,
  };

  components.TopBar = {
    name: 'TopBar',
    props: { title: String, subtitle: String },
    template: `
      <ui-panel class="topbar">
        <div class="topbar__text">
          <h1 class="topbar__title">{{ title }}</h1>
          <p class="topbar__sub">{{ subtitle }}</p>
        </div>
        <div class="topbar__actions">
          <connection-badge />
          <network-modal-button />
          <nightstand-toggle />
        </div>
      </ui-panel>`,
  };

  /* ========================================================================
     3. FEATURES
     ======================================================================== */

  /* ---- Tasks ---- */
  components.TaskRow = {
    name: 'TaskRow',
    props: { task: { type: Object, required: true } },
    setup(props) {
      const wyrm = inject('wyrm');
      const tone = computed(() => {
        const p = String(props.task.priority || '').toLowerCase();
        if (p.startsWith('h')) return 'high';
        if (p.startsWith('m')) return 'medium';
        if (p.startsWith('l')) return 'low';
        return null; // normal/unknown - the tablet hides the pill too
      });
      const label = computed(() => ({ high: 'High', medium: 'Medium', low: 'Low' }[tone.value]));
      return { wyrm, tone, label };
    },
    template: `
      <li class="task" :class="{ 'is-done': task.is_completed }">
        <button type="button" role="checkbox" class="check glass" :class="{ 'is-on': task.is_completed }"
                :aria-checked="!!task.is_completed" :aria-label="task.title"
                @click="wyrm.toggleTask(task.id)">
          <ui-icon v-if="task.is_completed" name="check" :size="16" :stroke="2.8" />
        </button>
        <span class="task__title">{{ task.title }}</span>
        <status-pill v-if="tone" :tone="tone">{{ label }}</status-pill>
        <ui-button size="icon" variant="danger" icon="x" :aria-label="'Delete ' + task.title"
                      @click="wyrm.deleteTask(task.id)" />
      </li>`,
  };

  components.TaskComposer = {
    name: 'TaskComposer',
    setup() {
      const wyrm = inject('wyrm');
      const title = ref('');
      const priority = ref('normal');
      const options = [
        { value: 'normal', label: 'Normal' },
        { value: 'low', label: 'Low' },
        { value: 'medium', label: 'Medium' },
        { value: 'high', label: 'High' },
      ];
      const fontLabel = computed(() => (wyrm.state.settings.cardFontSize || 14).toFixed(0) + ' pt');
      function submit() {
        if (wyrm.addTask(title.value, priority.value)) title.value = '';
      }
      return { wyrm, title, priority, options, fontLabel, submit };
    },
    template: `
      <ui-panel class="composer">
        <panel-head title="New task" subtitle="It appears on the tablet right away" icon="plus" />
        <div class="stack">
          <ui-input v-model="title" placeholder="What needs doing?" @enter="submit" />
          <segmented-control v-model="priority" :options="options" aria-label="Priority" />
          <ui-button variant="primary" icon="plus" :disabled="!title.trim()" @click="submit">Add task</ui-button>
        </div>
        <setting-row label="Text size" hint="For every card on the tablet">
          <stepper-control :label="fontLabel" @dec="wyrm.setFontSize(-1)" @inc="wyrm.setFontSize(1)" />
        </setting-row>
      </ui-panel>`,
  };

  /* ---- Habits ---- */
  const EMOJI_TO_ICON = {
    '💧': 'water_drop',
    '📖': 'menu_book',
    '🏋️': 'fitness_center',
    '🏋': 'fitness_center',
    '❤️': 'favorite',
    '❤': 'favorite',
    '🔥': 'bolt',
    '⚡': 'bolt',
    '💻': 'code',
    '☀️': 'wb_sunny',
    '☀': 'wb_sunny',
    '🌙': 'bedtime',
    '🎯': 'check_circle',
    '🌿': 'spa',
    '☕': 'local_cafe',
    '🏃': 'directions_run',
  };

  const ICON_TO_EMOJI = {
    'water_drop': '💧',
    'menu_book': '📖',
    'fitness_center': '🏋️',
    'favorite': '❤️',
    'bolt': '⚡',
    'code': '💻',
    'wb_sunny': '☀️',
    'bedtime': '🌙',
    'check_circle': '🎯',
    'spa': '🌿',
    'local_cafe': '☕',
    'directions_run': '🏃',
  };

  function habitGlyphToEmoji(raw) {
    if (!raw) return '⚡';
    return ICON_TO_EMOJI[raw] || raw;
  }

  components.GlyphPicker = {
    name: 'GlyphPicker',
    props: { modelValue: String },
    emits: ['update:modelValue'],
    setup(props, { emit }) {
      const presets = ['💧', '📖', '🏋️', '❤️', '🔥', '💻', '☀️', '🌙', '🎯', '🌿', '☕', '🏃'];
      const customEmoji = ref('');

      const isCustom = computed(() => {
        return props.modelValue && !presets.includes(props.modelValue);
      });

      function selectPreset(g) {
        customEmoji.value = '';
        emit('update:modelValue', g);
      }

      function onCustomInput(e) {
        const val = (e.target.value || '').trim();
        customEmoji.value = val;
        if (val) {
          emit('update:modelValue', val);
        }
      }

      return { presets, customEmoji, isCustom, selectPreset, onCustomInput };
    },
    template: `
      <div class="glyph-picker">
        <div class="glyphs" role="radiogroup" aria-label="Icon presets">
          <button v-for="g in presets" :key="g" type="button" role="radio" class="glyph glass"
                  :class="{ 'is-on': g === modelValue }" :aria-checked="g === modelValue"
                  @click="selectPreset(g)">{{ g }}</button>
        </div>
        <div class="glyph-custom-row">
          <input class="glyph-custom glass" :value="isCustom ? modelValue : customEmoji"
                 placeholder="Or type/paste custom emoji (e.g. 🍎)"
                 aria-label="Custom emoji"
                 @input="onCustomInput" />
        </div>
      </div>`,
  };

  components.HabitComposer = {
    name: 'HabitComposer',
    emits: ['done'],
    setup(props, { emit }) {
      const wyrm = inject('wyrm');
      const title = ref('');
      const type = ref('binary');
      const target = ref('8');
      const typeOptions = [
        { value: 'binary', label: 'Yes or no' },
        { value: 'numeric', label: 'Count' },
      ];
      function submit() {
        const ok = wyrm.createHabit({
          title: title.value,
          type: type.value,
          target: parseInt(target.value, 10) || 1,
          glyph: wyrm.draft.glyph,
        });
        if (ok) {
          title.value = '';
          emit('done');
        }
      }
      return { wyrm, title, type, target, typeOptions, submit };
    },
    template: `
      <ui-panel class="habit-composer">
        <panel-head title="New habit" subtitle="Pick how you want to track it" icon="leaf" />
        <div class="habit-composer__grid">
          <div class="stack">
            <ui-input v-model="title" placeholder="Habit name, like Drink water" @enter="submit" />
            <div class="habit-composer__row">
              <segmented-control v-model="type" :options="typeOptions" aria-label="Tracking type" />
              <ui-input v-if="type === 'numeric'" v-model="target" type="number" placeholder="Daily target" />
            </div>
          </div>
          <div class="stack">
            <glyph-picker v-model="wyrm.draft.glyph" />
            <ui-button variant="primary" icon="plus" :disabled="!title.trim()" @click="submit">Create habit</ui-button>
          </div>
        </div>
      </ui-panel>`,
  };

  components.WeekDots = {
    name: 'WeekDots',
    props: { habit: { type: Object, required: true } },
    setup() {
      const wyrm = inject('wyrm');
      const days = computed(() => {
        const now = new Date();
        const out = [];
        for (let i = 6; i >= 0; i--) {
          const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
          out.push({
            key: wyrm.dateKey(d),
            label: d.toLocaleDateString('en-US', { weekday: 'narrow' }),
            isToday: i === 0,
          });
        }
        return out;
      });
      return { wyrm, days };
    },
    template: `
      <div class="week">
        <div v-for="d in days" :key="d.key" class="week__col" :class="{ 'is-today': d.isToday }">
          <span class="week__dot" :class="{ 'is-on': wyrm.habitDayCompleted(habit, d.key) }"></span>
          <span class="week__label">{{ d.label }}</span>
        </div>
      </div>`,
  };

  components.HabitCard = {
    name: 'HabitCard',
    props: { habit: { type: Object, required: true } },
    setup(props) {
      const wyrm = inject('wyrm');
      const done = computed(() => wyrm.isHabitCompletedToday(props.habit));
      const isBinary = computed(() => !props.habit.type || props.habit.type === 'binary');
      const streak = computed(() => {
        const n = props.habit.currentStreak || 0;
        return n ? n + '-day streak' : 'No streak yet';
      });
      const habitGlyph = computed(() => {
        const raw = props.habit.iconName || props.habit.icon_name;
        return habitGlyphToEmoji(raw);
      });
      const progress = computed(() => {
        const current = wyrm.getHabitTodayValue(props.habit);
        const target = props.habit.targetValue || props.habit.target_value || 1;
        const unit = (props.habit.unit || '').trim();
        return unit ? `${current} of ${target} ${unit}` : `${current} of ${target}`;
      });
      return { wyrm, done, isBinary, streak, habitGlyph, progress };
    },
    template: `
      <ui-panel class="habit" :class="{ 'is-done': done }">
        <div class="habit__top">
          <span class="habit__glyph glass">{{ habitGlyph }}</span>
          <div class="habit__heading">
            <h3 class="habit__title">{{ habit.title }}</h3>
            <status-pill :tone="habit.currentStreak ? 'accent' : 'neutral'">{{ streak }}</status-pill>
          </div>
          <ui-button size="icon" variant="danger" icon="x" :aria-label="'Delete ' + habit.title"
                        @click="wyrm.deleteHabit(habit.id)" />
        </div>
        <ui-button v-if="isBinary" :variant="done ? 'primary' : 'default'" :icon="done ? 'check' : null"
                      @click="wyrm.toggleHabit(habit.id)">{{ done ? 'Done today' : 'Mark done' }}</ui-button>
        <stepper-control v-else :label="progress" @dec="wyrm.stepHabit(habit.id, -1)" @inc="wyrm.stepHabit(habit.id, 1)" />
        <week-dots :habit="habit" />
      </ui-panel>`,
  };

  /* ---- Calendar ---- */
  components.MonthGrid = {
    name: 'MonthGrid',
    props: { viewDate: { type: Date, required: true }, selected: String },
    emits: ['select'],
    setup(props) {
      const wyrm = inject('wyrm');
      const mondayFirst = computed(() => !!wyrm.state.settings.startWeekOnMonday);

      const headers = computed(() => {
        // 2023-01-01 is a Sunday.
        const out = [];
        for (let i = 0; i < 7; i++) {
          const d = new Date(2023, 0, 1 + i + (mondayFirst.value ? 1 : 0));
          out.push(d.toLocaleDateString('en-US', { weekday: 'narrow' }));
        }
        return out;
      });

      const markedKeys = computed(() => {
        const set = new Set();
        (wyrm.state.calendar.milestones || []).forEach((m) => {
          const d = new Date(m.targetDate);
          if (!isNaN(d.getTime())) set.add(wyrm.dateKey(d));
        });
        return set;
      });

      const cells = computed(() => {
        const year = props.viewDate.getFullYear();
        const month = props.viewDate.getMonth();
        const makeDate = (y, m, d) => {
          const dt = new Date(y, m, d);
          if (y >= 0 && y < 100) dt.setFullYear(y);
          return dt;
        };
        const first = makeDate(year, month, 1);
        const lead = mondayFirst.value ? (first.getDay() + 6) % 7 : first.getDay();
        const daysInMonth = makeDate(year, month + 1, 0).getDate();
        const total = Math.ceil((lead + daysInMonth) / 7) * 7;
        const todayKey = wyrm.dateKey();
        const out = [];
        for (let i = 0; i < total; i++) {
          const d = makeDate(year, month, 1 - lead + i);
          const key = wyrm.dateKey(d);
          out.push({
            key,
            date: d,
            num: d.getDate(),
            inMonth: d.getMonth() === month,
            isToday: key === todayKey,
            hasMilestone: markedKeys.value.has(key),
            label: d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }),
          });
        }
        return out;
      });

      return { headers, cells };
    },
    template: `
      <div class="month">
        <div class="month__head" aria-hidden="true"><span v-for="(h, i) in headers" :key="i">{{ h }}</span></div>
        <div class="month__grid">
          <button v-for="c in cells" :key="c.key" type="button" class="day"
                  :class="{ 'is-out': !c.inMonth, 'is-today': c.isToday, 'is-selected': c.key === selected }"
                  :aria-label="c.label" :aria-current="c.isToday ? 'date' : null"
                  @click="$emit('select', c.date)">
            <span>{{ c.num }}</span>
            <i v-if="c.hasMilestone" class="day__mark"></i>
          </button>
        </div>
      </div>`,
  };

  components.MilestoneRow = {
    name: 'MilestoneRow',
    props: { milestone: { type: Object, required: true } },
    setup() {
      return { wyrm: inject('wyrm') };
    },
    template: `
      <li class="ms" :class="{ 'is-pinned': milestone.isPinned }">
        <ui-button size="icon" variant="ghost" icon="star" :active="milestone.isPinned"
                      :aria-pressed="!!milestone.isPinned" aria-label="Pin to tablet"
                      @click="wyrm.togglePinMilestone(milestone.id)" />
        <div class="ms__text">
          <div class="ms__title">{{ milestone.title }}</div>
          <div class="ms__date">{{ wyrm.formatMilestoneDate(milestone.targetDate) }}</div>
        </div>
        <status-pill tone="neutral">{{ wyrm.milestoneCountdown(milestone.targetDate) }}</status-pill>
        <ui-button size="icon" variant="danger" icon="x" :aria-label="'Delete ' + milestone.title"
                      @click="wyrm.deleteMilestone(milestone.id)" />
      </li>`,
  };

  components.MilestonesPanel = {
    name: 'MilestonesPanel',
    setup() {
      const wyrm = inject('wyrm');
      const title = ref('');
      const isoDate = ref('');
      const pinned = ref(false);
      const milestones = computed(() => wyrm.state.calendar.milestones || []);

      function submit() {
        const [y, m, d] = isoDate.value.split('-');
        if (!y || !m || !d) return;
        const ok = wyrm.createMilestone({ title: title.value, date: d + '/' + m + '/' + y, pinned: pinned.value });
        if (ok) {
          title.value = '';
          isoDate.value = '';
          pinned.value = false;
        }
      }
      return { wyrm, title, isoDate, pinned, milestones, submit };
    },
    template: `
      <ui-panel class="milestones">
        <panel-head title="Milestones" subtitle="Dates you're counting down to" icon="star" />
        <div class="stack">
          <ui-input v-model="title" placeholder="Milestone name" @enter="submit" />
          <div class="ms-compose">
            <date-field v-model="isoDate" aria-label="Target date" />
            <ui-button size="icon" icon="star" :active="pinned" :aria-pressed="pinned"
                          aria-label="Pin to tablet" title="Pin to tablet" @click="pinned = !pinned" />
            <ui-button variant="primary" icon="plus" :disabled="!title.trim() || !isoDate" @click="submit">Add</ui-button>
          </div>
        </div>
        <transition-group v-if="milestones.length" tag="ul" name="list" class="list">
          <milestone-row v-for="m in milestones" :key="m.id" :milestone="m" />
        </transition-group>
        <empty-state v-else icon="calendar" title="No milestones yet" hint="Add a date to count down to it." />
      </ui-panel>`,
  };

  components.TravelModal = {
    name: 'TravelModal',
    props: {
      initialDate: { type: [Date, String], default: () => new Date() },
    },
    emits: ['close', 'travel'],
    setup(props, { emit }) {
      const wyrm = inject('wyrm');
      const MONTH_NAMES = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      const SHORT_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      // Follows the same "week starts on" setting as the calendar behind it.
      const mondayFirst = computed(() => !!wyrm.state.settings.startWeekOnMonday);
      const weekdayHeaders = computed(() =>
        mondayFirst.value ? ['M', 'T', 'W', 'T', 'F', 'S', 'S'] : ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      );
      const yearsEl = ref(null);

      const initial = props.initialDate ? new Date(props.initialDate) : new Date();
      const initialYear = Math.max(1, Math.min(9999, initial.getFullYear()));
      const selectedYear = ref(initialYear);
      const selectedMonth = ref(initial.getMonth());
      const selectedDay = ref(initial.getDate());
      const mode = ref('day'); // 'day' | 'month' | 'year'

      function makeDate(y, m, d, h = 0, min = 0, s = 0) {
        const dt = new Date(y, m, d, h, min, s);
        if (y >= 0 && y < 100) dt.setFullYear(y);
        return dt;
      }

      function computeInitialBounds(targetYear) {
        let start = targetYear - 30;
        let end = targetYear + 29;
        if (start < 1) {
          end = Math.min(9999, end + (1 - start));
          start = 1;
        }
        if (end > 9999) {
          start = Math.max(1, start - (end - 9999));
          end = 9999;
        }
        return { start, end };
      }

      const initialBounds = computeInitialBounds(initialYear);
      const minLoadedYear = ref(initialBounds.start);
      const maxLoadedYear = ref(initialBounds.end);

      const yearsList = computed(() => {
        const list = [];
        for (let y = minLoadedYear.value; y <= maxLoadedYear.value; y++) {
          list.push(y);
        }
        return list;
      });

      function clampDay() {
        const maxDays = makeDate(selectedYear.value, selectedMonth.value + 1, 0).getDate();
        if (selectedDay.value > maxDays) selectedDay.value = maxDays;
      }

      function toggleMonthMode() {
        mode.value = mode.value === 'month' ? 'day' : 'month';
      }

      function toggleYearMode() {
        mode.value = mode.value === 'year' ? 'day' : 'year';
        if (mode.value === 'year') {
          if (selectedYear.value < minLoadedYear.value || selectedYear.value > maxLoadedYear.value) {
            const bounds = computeInitialBounds(selectedYear.value);
            minLoadedYear.value = bounds.start;
            maxLoadedYear.value = bounds.end;
          }
          nextTick(() => {
            const box = yearsEl.value;
            const tile = box && box.querySelector('.is-selected');
            if (tile && box) {
              box.scrollTop = tile.offsetTop - box.clientHeight / 2 + tile.offsetHeight / 2;
            }
          });
        }
      }

      function onYearsScroll(e) {
        const box = e.target;
        if (!box) return;
        const { scrollTop, scrollHeight, clientHeight } = box;

        // Near top (within 150px): prepend up to 30 years down to Year 1 (AC)
        if (scrollTop <= 150 && minLoadedYear.value > 1) {
          const delta = Math.min(30, minLoadedYear.value - 1);
          if (delta > 0) {
            const prevScrollHeight = box.scrollHeight;
            minLoadedYear.value -= delta;
            nextTick(() => {
              const diff = box.scrollHeight - prevScrollHeight;
              box.scrollTop += diff;
            });
          }
        }

        // Near bottom (within 150px): append up to 30 years up to Year 9999
        if (scrollHeight - scrollTop - clientHeight <= 150 && maxLoadedYear.value < 9999) {
          const delta = Math.min(30, 9999 - maxLoadedYear.value);
          if (delta > 0) {
            maxLoadedYear.value += delta;
          }
        }
      }

      function shift(delta) {
        if (mode.value === 'day') {
          let newM = selectedMonth.value + delta;
          let newY = selectedYear.value;
          if (newM < 0) {
            newM = 11;
            newY--;
          } else if (newM > 11) {
            newM = 0;
            newY++;
          }
          selectedYear.value = Math.max(1, Math.min(9999, newY));
          selectedMonth.value = newM;
          clampDay();
        } else if (mode.value === 'year') {
          const target = Math.max(1, Math.min(9999, selectedYear.value + delta * 3));
          selectedYear.value = target;
          if (target < minLoadedYear.value) {
            minLoadedYear.value = Math.max(1, target - 15);
          } else if (target > maxLoadedYear.value) {
            maxLoadedYear.value = Math.min(9999, target + 15);
          }
        } else {
          selectedYear.value = Math.max(1, Math.min(9999, selectedYear.value + delta));
        }
      }

      function setMonth(m) {
        selectedMonth.value = m;
        clampDay();
        mode.value = 'day';
      }

      function setYear(y) {
        selectedYear.value = Math.max(1, Math.min(9999, y));
        clampDay();
        mode.value = 'day';
      }

      function setDay(d, mDelta = 0) {
        if (mDelta !== 0) {
          shift(mDelta);
        }
        selectedDay.value = d;
      }

      const dayCells = computed(() => {
        const y = selectedYear.value;
        const m = selectedMonth.value;
        const firstDay = makeDate(y, m, 1);
        const daysInCur = makeDate(y, m + 1, 0).getDate();
        const prevMonthDays = makeDate(y, m, 0).getDate();

        const offset = mondayFirst.value ? (firstDay.getDay() + 6) % 7 : firstDay.getDay();
        const total = Math.ceil((offset + daysInCur) / 7) * 7;
        const cells = [];

        for (let i = 0; i < total; i++) {
          const dayNum = i - offset + 1;
          if (dayNum < 1) {
            const num = prevMonthDays + dayNum;
            cells.push({ num, inMonth: false, delta: -1, isSelected: false });
          } else if (dayNum > daysInCur) {
            const num = dayNum - daysInCur;
            cells.push({ num, inMonth: false, delta: 1, isSelected: false });
          } else {
            const isSel = dayNum === selectedDay.value;
            const now = new Date();
            const isToday = now.getFullYear() === y && now.getMonth() === m && now.getDate() === dayNum;
            cells.push({ num: dayNum, inMonth: true, delta: 0, isSelected: isSel, isToday });
          }
        }
        return cells;
      });

      const selectedDateFormatted = computed(() => {
        const d = makeDate(selectedYear.value, selectedMonth.value, selectedDay.value);
        return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
      });

      function confirm() {
        const target = makeDate(selectedYear.value, selectedMonth.value, selectedDay.value, 12, 0, 0);
        emit('travel', target);
      }

      useModal(emit);

      return {
        monthNames: MONTH_NAMES,
        shortMonths: SHORT_MONTHS,
        weekdayHeaders,
        yearsEl,
        yearsList,
        onYearsScroll,
        selectedYear,
        selectedMonth,
        selectedDay,
        mode,
        dayCells,
        selectedDateFormatted,
        toggleMonthMode,
        toggleYearMode,
        shift,
        setMonth,
        setYear,
        setDay,
        confirm,
      };
    },
    template: `
      <teleport to="body">
        <div class="modal-backdrop" @click.self="$emit('close')">
          <ui-panel class="modal-card modal-card--travel" data-tone="gold" role="dialog" aria-modal="true" aria-label="Time travel">
            <panel-head title="Time travel" :subtitle="selectedDateFormatted" icon="compass">
              <ui-button size="icon" icon="x" aria-label="Close" @click="$emit('close')" />
            </panel-head>

            <div class="cal-toolbar">
              <div class="travel-chips">
                <button type="button" class="btn btn--sm travel-chip" :class="{ 'is-active': mode === 'month' }"
                        :aria-expanded="mode === 'month'" @click="toggleMonthMode">
                  <span class="travel-chip__full">{{ monthNames[selectedMonth] }}</span>
                  <span class="travel-chip__short">{{ shortMonths[selectedMonth] }}</span>
                  <ui-icon name="chevron-down" :size="16" class="travel-chip__arrow" />
                </button>
                <button type="button" class="btn btn--sm travel-chip" :class="{ 'is-active': mode === 'year' }"
                        :aria-expanded="mode === 'year'" @click="toggleYearMode">
                  <span>{{ selectedYear }}</span>
                  <ui-icon name="chevron-down" :size="16" class="travel-chip__arrow" />
                </button>
              </div>
              <div v-if="mode === 'day'" class="cal-nav">
                <ui-button size="icon" variant="ghost" icon="chevron-left" aria-label="Previous month" @click="shift(-1)" />
                <ui-button size="icon" variant="ghost" icon="chevron-right" aria-label="Next month" @click="shift(1)" />
              </div>
            </div>

            <div class="travel-picker-body">
              <div v-if="mode === 'day'" class="travel-day-view">
                <div class="travel-weekdays" aria-hidden="true">
                  <span v-for="(h, i) in weekdayHeaders" :key="i">{{ h }}</span>
                </div>
                <div class="travel-days-grid">
                  <button v-for="(c, i) in dayCells" :key="i" type="button" class="day"
                          :class="{ 'is-out': !c.inMonth, 'is-selected': c.isSelected, 'is-today': c.isToday }"
                          :aria-pressed="c.isSelected" @click="setDay(c.num, c.delta)">
                    <span>{{ c.num }}</span>
                  </button>
                </div>
              </div>

              <div v-else-if="mode === 'month'" class="travel-months-grid">
                <button v-for="(mName, idx) in shortMonths" :key="idx" type="button" class="day travel-month-tile"
                        :class="{ 'is-selected': selectedMonth === idx }" @click="setMonth(idx)">
                  <span>{{ mName }}</span>
                </button>
              </div>

              <div v-else class="travel-years-scroll" ref="yearsEl" @scroll="onYearsScroll">
                <button v-for="y in yearsList" :key="y" type="button" class="day travel-year-tile"
                        :class="{ 'is-selected': selectedYear === y }" @click="setYear(y)">
                  <span>{{ y }}</span>
                </button>
              </div>
            </div>

            <div class="travel-actions">
              <ui-button variant="ghost" @click="$emit('close')">Cancel</ui-button>
              <ui-button variant="primary" icon="compass" @click="confirm">Travel</ui-button>
            </div>
          </ui-panel>
        </div>
      </teleport>`,
  };

  /* ========================================================================
     4. VIEWS
     ======================================================================== */

  const SIZE_OPTIONS = [
    { value: 'small', label: 'Small' },
    { value: 'medium', label: 'Medium' },
    { value: 'fullscreen', label: 'Full' },
  ];
  const CLOCK_OPTIONS = [...SIZE_OPTIONS, { value: 'nightstand', label: 'Night', tone: 'night' }];

  components.DeckTile = {
    name: 'DeckTile',
    props: {
      id: { type: String, required: true },
      label: String,
      hint: String,
      icon: String,
      tone: String,
    },
    setup(props) {
      const wyrm = inject('wyrm');
      const options = computed(() => (props.id === 'clock' ? CLOCK_OPTIONS : SIZE_OPTIONS));
      return { wyrm, options };
    },
    template: `
      <ui-panel class="deck-tile" :data-tone="tone">
        <div class="deck-tile__top">
          <span class="deck-tile__icon glass"><ui-icon :name="icon" :size="24" /></span>
          <div class="deck-tile__text">
            <h3 class="deck-tile__title">{{ label }}</h3>
            <p class="deck-tile__hint">{{ hint }}</p>
          </div>
          <ui-button size="icon" variant="ghost" icon="locate" :aria-label="'Show ' + label + ' on the tablet'"
                        title="Show on the tablet" @click="wyrm.scrollToCard(id)" />
        </div>
        <segmented-control :model-value="wyrm.state.layout[id]" :options="options" :aria-label="label + ' size'"
                           @update:model-value="(v) => wyrm.setCardSize(id, v)" />
      </ui-panel>`,
  };

  components.ViewDeck = {
    name: 'ViewDeck',
    setup() {
      const wyrm = inject('wyrm');
      const cards = [
        { id: 'clock', label: 'Clock', hint: 'Time and date', icon: 'clock', tone: 'slate' },
        { id: 'habits', label: 'Habits', hint: "Today's progress", icon: 'leaf', tone: 'teal' },
        { id: 'calendar', label: 'Calendar', hint: 'Month and milestones', icon: 'calendar', tone: 'gold' },
        { id: 'tasks', label: 'Tasks', hint: 'Your open list', icon: 'checkbox', tone: 'rust' },
        { id: 'reminder', label: 'Reminders', hint: 'Timed alarms · Coming soon', icon: 'bell', tone: 'plum' },
        { id: 'sharing', label: 'Sharing', hint: 'LAN file transfer · Coming soon', icon: 'share', tone: 'cobalt' },
      ];
      const allSize = computed(() => {
        const sizes = cards.map((c) => wyrm.state.layout[c.id]);
        return sizes.every((s) => s === sizes[0]) ? sizes[0] : null;
      });
      return { wyrm, cards, allSize, sizeOptions: SIZE_OPTIONS };
    },
    template: `
      <div class="view view--deck">
        <ui-panel class="deck-all">
          <panel-head title="All cards" subtitle="Give every card on the tablet the same size" icon="grid" />
          <segmented-control :model-value="allSize" :options="sizeOptions" aria-label="Size for all cards"
                             @update:model-value="(v) => wyrm.setAllCardsSize(v)" />
        </ui-panel>
        <div class="deck-grid">
          <deck-tile v-for="c in cards" :key="c.id" v-bind="c" />
        </div>
      </div>`,
  };

  components.ViewTasks = {
    name: 'ViewTasks',
    setup() {
      const wyrm = inject('wyrm');
      const tasks = computed(() => wyrm.state.tasks);
      const subtitle = computed(() => {
        const open = tasks.value.filter((t) => !t.is_completed).length;
        return open + ' open of ' + tasks.value.length;
      });
      return { tasks, subtitle };
    },
    template: `
      <div class="view view--tasks">
        <task-composer />
        <ui-panel class="task-panel">
          <panel-head title="Your list" :subtitle="subtitle" icon="checkbox" />
          <transition-group v-if="tasks.length" tag="ul" name="list" class="list">
            <task-row v-for="t in tasks" :key="t.id" :task="t" />
          </transition-group>
          <empty-state v-else icon="tasks" title="No tasks yet" hint="Add one and it shows up on the tablet." />
        </ui-panel>
      </div>`,
  };

  components.ViewHabits = {
    name: 'ViewHabits',
    setup() {
      const wyrm = inject('wyrm');
      const composing = ref(false);
      const habits = computed(() => wyrm.state.habits);
      const summary = computed(() => {
        const done = habits.value.filter((h) => wyrm.isHabitCompletedToday(h)).length;
        return habits.value.length ? done + ' of ' + habits.value.length + ' done today' : 'Nothing tracked yet';
      });
      return { composing, habits, summary };
    },
    template: `
      <div class="view view--habits">
        <div class="toolbar">
          <p class="toolbar__summary">{{ summary }}</p>
          <ui-button :variant="composing ? 'default' : 'primary'" :icon="composing ? 'x' : 'plus'"
                        @click="composing = !composing">{{ composing ? 'Cancel' : 'New habit' }}</ui-button>
        </div>
        <transition name="drop">
          <habit-composer v-if="composing" @done="composing = false" />
        </transition>
        <transition-group v-if="habits.length" tag="div" name="list" class="habit-grid">
          <habit-card v-for="h in habits" :key="h.id" :habit="h" />
        </transition-group>
        <ui-panel v-else-if="!composing">
          <empty-state icon="sprout" title="No habits yet" hint="Create one to start a streak." />
        </ui-panel>
      </div>`,
  };

  components.CalDateCard = {
    name: 'CalDateCard',
    props: {
      date: { type: [Date, String], default: () => new Date() },
    },
    setup(props) {
      const d = computed(() => (props.date instanceof Date ? props.date : new Date(props.date)));

      const dayNumber = computed(() => d.value.getDate());
      const weekday = computed(() => d.value.toLocaleDateString('en-US', { weekday: 'long' }));
      const monthYear = computed(() => d.value.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }));

      // Day-of-year from UTC midnights, so daylight saving can never shift the count by one.
      const year = computed(() => {
        const cur = d.value;
        const y = cur.getFullYear();
        const dayOfYear = Math.round((Date.UTC(y, cur.getMonth(), cur.getDate()) - Date.UTC(y, 0, 1)) / 86400000) + 1;
        const daysInYear = (y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0)) ? 366 : 365;
        return { dayOfYear, daysInYear, pct: Math.round((dayOfYear / daysInYear) * 100) };
      });

      return { dayNumber, weekday, monthYear, year };
    },
    template: `
      <ui-panel class="cal-date-card" data-tone="gold">
        <div class="cal-date-card__body">
          <div class="cal-date-card__day">{{ dayNumber }}</div>
          <div class="cal-date-card__meta">
            <div class="cal-date-card__weekday">{{ weekday }}</div>
            <div class="cal-date-card__month-year">{{ monthYear }}</div>
          </div>
        </div>
        <div class="cal-date-card__chips">
          <span class="cal-date-card__chip"><i class="cal-date-card__dot"></i>Day {{ year.dayOfYear }}/{{ year.daysInYear }}</span>
          <span class="cal-date-card__chip">Year {{ year.pct }}%</span>
        </div>
      </ui-panel>`,
  };

  components.TravelInsightCard = {
    name: 'TravelInsightCard',
    props: {
      date: { type: [Date, String], required: true },
    },
    emits: ['reset'],
    setup(props) {
      const wyrm = inject('wyrm');
      const d = computed(() => (props.date instanceof Date ? props.date : new Date(props.date)));

      const formatted = computed(() =>
        d.value.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })
      );

      const diffDays = computed(() => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const target = new Date(d.value);
        target.setHours(0, 0, 0, 0);
        return Math.round((target.getTime() - today.getTime()) / 86400000);
      });

      const distance = computed(() => {
        const n = diffDays.value;
        if (n === 0) return 'Today';
        if (n === 1) return 'Tomorrow';
        if (n === -1) return 'Yesterday';
        return n > 0 ? 'In ' + n + ' days' : Math.abs(n) + ' days ago';
      });

      const breakdown = computed(() => {
        const abs = Math.abs(diffDays.value);
        if (abs < 7) return '';
        const weeks = Math.floor(abs / 7);
        const rem = abs % 7;
        return rem ? weeks + 'w ' + rem + 'd' : weeks + (weeks === 1 ? ' week' : ' weeks');
      });

      const milestonesOnDate = computed(() => {
        const key = wyrm.dateKey(d.value);
        return (wyrm.state.calendar.milestones || []).filter((m) => wyrm.dateKey(new Date(m.targetDate)) === key);
      });

      return { formatted, distance, breakdown, milestonesOnDate };
    },
    template: `
      <ui-panel class="travel-insight" data-tone="gold">
        <panel-head title="Time travel" :subtitle="formatted" icon="compass">
          <ui-button size="sm" variant="primary" icon="check" @click="$emit('reset')">Today</ui-button>
        </panel-head>
        <div class="travel-insight__chips">
          <status-pill tone="accent">{{ distance }}</status-pill>
          <status-pill v-if="breakdown" tone="neutral">{{ breakdown }}</status-pill>
        </div>
        <div v-if="milestonesOnDate.length" class="travel-insight__milestones">
          <div class="travel-insight__ms-head">Milestones that day</div>
          <ul class="travel-insight__ms-list">
            <li v-for="m in milestonesOnDate" :key="m.id" class="travel-insight__ms-item">
              <ui-icon name="star" :size="16" />
              <span>{{ m.title }}</span>
            </li>
          </ul>
        </div>
      </ui-panel>`,
  };

  components.ViewCalendar = {
    name: 'ViewCalendar',
    setup() {
      const wyrm = inject('wyrm');
      const viewDate = ref(new Date()); // which month the grid shows
      const selectedDate = ref(new Date()); // the day the tablet is pointed at
      const selectedKey = ref(wyrm.dateKey());
      const showTravel = ref(false);

      const isTraveled = computed(() => selectedKey.value !== wyrm.dateKey(new Date()));
      const monthLabel = computed(() => viewDate.value.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }));

      const metrics = computed(() => {
        const now = new Date();
        const pct = (from, to) => Math.min(100, Math.max(0, Math.round(((now - from) / (to - from)) * 100)));
        const quarter = Math.floor(now.getMonth() / 3) + 1;
        return {
          quarter,
          year: pct(new Date(now.getFullYear(), 0, 1), new Date(now.getFullYear() + 1, 0, 1)),
          quarterPct: pct(new Date(now.getFullYear(), (quarter - 1) * 3, 1), new Date(now.getFullYear(), quarter * 3, 1)),
        };
      });

      function pick(date) {
        selectedDate.value = new Date(date);
        selectedKey.value = wyrm.dateKey(date);
        viewDate.value = new Date(date);
      }
      function shift(delta) {
        viewDate.value = new Date(viewDate.value.getFullYear(), viewDate.value.getMonth() + delta, 1);
      }
      function today() {
        const now = new Date();
        pick(now);
        wyrm.travelToDate(now);
      }
      function select(date) {
        pick(date);
        wyrm.travelToDate(date);
      }
      function travel(date) {
        pick(date);
        wyrm.travelToDate(date);
        showTravel.value = false;
      }
      return { viewDate, selectedDate, selectedKey, isTraveled, monthLabel, metrics, shift, today, select, showTravel, travel };
    },
    template: `
      <div class="view view--cal">
        <ui-panel class="cal-main">
          <panel-head title="Calendar" icon="calendar">
            <ui-button class="travel-btn" size="sm" icon="compass" :active="isTraveled" aria-label="Time travel" @click="showTravel = true">Travel</ui-button>
          </panel-head>
          <div class="cal-toolbar">
            <h3 class="cal-toolbar__month">{{ monthLabel }}</h3>
            <div class="cal-nav">
              <ui-button size="icon" variant="ghost" icon="chevron-left" aria-label="Previous month" @click="shift(-1)" />
              <ui-button size="sm" @click="today">Today</ui-button>
              <ui-button size="icon" variant="ghost" icon="chevron-right" aria-label="Next month" @click="shift(1)" />
            </div>
          </div>
          <month-grid :view-date="viewDate" :selected="selectedKey" @select="select" />
        </ui-panel>
        <travel-modal v-if="showTravel" :initial-date="selectedDate" @close="showTravel = false" @travel="travel" />
        <div class="cal-side">
          <cal-date-card :date="selectedDate" />
          <travel-insight-card v-if="isTraveled" :date="selectedDate" @reset="today" />
          <ui-panel class="cal-progress">
            <panel-head title="Progress" icon="pulse" />
            <div class="meters">
              <progress-meter label="This year" :percent="metrics.year" />
              <progress-meter :label="'Quarter ' + metrics.quarter" :percent="metrics.quarterPct" />
            </div>
          </ui-panel>
          <milestones-panel />
        </div>
      </div>`,
  };

  components.ViewSettings = {
    name: 'ViewSettings',
    setup() {
      const wyrm = inject('wyrm');
      const brightness = computed(() =>
        wyrm.state.display && wyrm.state.display.brightness != null
          ? wyrm.state.display.brightness
          : 1.0
      );
      const fileInput = ref(null);
      const importing = ref(false);
      const backupMessage = ref('');
      const backupSuccess = ref(true);

      function exportBackup() {
        wyrm.exportBackup();
      }

      function triggerFileInput() {
        if (fileInput.value) {
          fileInput.value.value = '';
          fileInput.value.click();
        }
      }

      async function onFileSelected(e) {
        const file = e.target.files && e.target.files[0];
        if (!file) return;
        importing.value = true;
        backupMessage.value = '';
        try {
          const text = await file.text();
          await wyrm.importBackup(text);
          backupSuccess.value = true;
          backupMessage.value = 'Backup imported and dashboard updated!';
        } catch (err) {
          backupSuccess.value = false;
          backupMessage.value = err.message || 'Failed to import backup.';
        } finally {
          importing.value = false;
        }
      }

      return {
        wyrm,
        brightness,
        pct: computed(() => Math.round(brightness.value * 100)),
        timeOptions: [
          { value: false, label: '12-hour' },
          { value: true, label: '24-hour' },
        ],
        weekOptions: [
          { value: false, label: 'Sunday' },
          { value: true, label: 'Monday' },
        ],
        fileInput,
        importing,
        backupMessage,
        backupSuccess,
        exportBackup,
        triggerFileInput,
        onFileSelected,
      };
    },
    template: `
      <div class="view view--settings">
        <ui-panel>
          <panel-head title="Display" subtitle="Brightness of the tablet screen" icon="sun" />
          <div class="brightness">
            <ui-icon name="sun" :size="20" />
            <ui-slider :model-value="brightness" :min="0.05" :max="1" :step="0.01"
                          @update:model-value="(v) => wyrm.setBrightness(v)" />
            <span class="brightness__value">{{ pct }}%</span>
          </div>
        </ui-panel>

        <ui-panel>
          <panel-head title="Clock and calendar" icon="clock" />
          <setting-row label="Time format">
            <segmented-control :model-value="!!wyrm.state.settings.is24HourFormat" :options="timeOptions"
                               aria-label="Time format" @update:model-value="(v) => wyrm.set24HourFormat(v)" />
          </setting-row>
          <setting-row label="Week starts on">
            <segmented-control :model-value="!!wyrm.state.settings.startWeekOnMonday" :options="weekOptions"
                               aria-label="First day of the week" @update:model-value="(v) => wyrm.setStartWeekOnMonday(v)" />
          </setting-row>
        </ui-panel>

        <ui-panel>
          <panel-head title="Data & backup" subtitle="Transfer or restore dashboard data" icon="database" />
          <setting-row label="Export backup" hint="Download a complete snapshot of all cards, tasks, and settings as JSON">
            <button class="btn btn--secondary btn--sm" type="button" @click="exportBackup">
              Download JSON
            </button>
          </setting-row>
          <setting-row label="Restore backup" hint="Replace tablet data with an uploaded JSON backup file">
            <input type="file" ref="fileInput" accept=".json,application/json" style="display: none" @change="onFileSelected" />
            <button class="btn btn--secondary btn--sm" type="button" @click="triggerFileInput" :disabled="importing">
              {{ importing ? 'Importing…' : 'Upload JSON' }}
            </button>
          </setting-row>
          <div v-if="backupMessage" :class="['backup-status', backupSuccess ? 'backup-status--success' : 'backup-status--error']" style="margin-top: 10px; font-size: 13px; padding: 8px 12px; border-radius: 6px; background: rgba(255,255,255,0.06); color: var(--text);">
            {{ backupMessage }}
          </div>
        </ui-panel>
      </div>`,
  };

  /* ========================================================================
     5. ROOT
     ======================================================================== */

  components.WyrmApp = {
    name: 'WyrmApp',
    setup() {
      const wyrm = inject('wyrm');
      const current = computed(() => DESTINATIONS.find((d) => d.id === wyrm.state.currentChannel) || DESTINATIONS[0]);
      const night = computed(() => wyrm.state.layout.clock === 'nightstand');

      const subtitle = computed(() => {
        switch (current.value.id) {
          case 'tasks': {
            const open = wyrm.state.tasks.filter((t) => !t.is_completed).length;
            return open ? open + ' open' : 'All clear';
          }
          case 'habits': {
            const hs = wyrm.state.habits;
            return hs.length ? hs.filter((h) => wyrm.isHabitCompletedToday(h)).length + ' of ' + hs.length + ' done today' : 'Build a streak';
          }
          case 'cal':
            return new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
          case 'sys':
            return 'Display and clock';
          default:
            return 'How each card appears on the tablet';
        }
      });

      const networkModalOpen = computed(() => !!wyrm.state.networkModalOpen);

      return { wyrm, current, night, subtitle, networkModalOpen };
    },
    template: `
      <div class="app" :class="{ 'is-nightstand': night }" :data-view="current.id" :data-tone="current.tone">
        <backdrop-scene />
        <nav-rail />
        <div class="app__main">
          <top-bar :title="current.label" :subtitle="subtitle" />
          <main class="app__content">
            <transition name="view" mode="out-in">
              <component :is="current.view" :key="current.id" />
            </transition>
          </main>
        </div>
        <network-modal v-if="networkModalOpen" @close="wyrm.toggleNetworkModal(false)" />
      </div>`,
  };

  /* ========================================================================
     INSTALL
     ======================================================================== */
  function kebab(name) {
    return name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();
  }

  window.WyrmUI = {
    components,
    directives,
    destinations: DESTINATIONS,
    install(app) {
      Object.keys(components).forEach((name) => app.component(kebab(name), components[name]));
      Object.keys(directives).forEach((name) => app.directive(name, directives[name]));
    },
  };
})();
