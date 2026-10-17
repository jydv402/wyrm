# WYRM Desk — Project Specsheet & Agent Guide

> **Purpose of this document.** This is the single source of truth for anyone (human or
> agent) working in this repository. It describes what the app is, how it is structured,
> every data model, the full server API surface, the web-remote protocol, the design
> system, and the conventions to follow. Read this before changing code.
>
> If you find a conflict between this file and another doc in the repo, trust **this file
> and the source code**. `REFERENCE_STATE.md` and `docs/web_remote_architecture.md`
> describe an *earlier, partly-abandoned* design and are stale (see §17).

---

## 1. What this project is

**WYRM Desk** is a Flutter **desk companion app** for older Android tablets used as an
ambient landscape display (a "bento" dashboard of Clock / Habits / Calendar / Tasks
cards). The tablet runs an **embedded HTTP + WebSocket server** on the local network and
**hosts a plain HTML/CSS/JS website** (the "web remote") so any phone or laptop on the
same Wi-Fi can control the tablet dashboard.

- No cloud, no backend, no accounts. Everything is local-network only.
- The **tablet is the server and the single source of truth** for data.
- The **web remote is a dumb client**: it renders a snapshot pushed by the tablet and
  sends mutations back over WebSocket (with a REST fallback).
- Data is persisted on the device as a single JSON document.

### Core product intents

| Intent | Where it lives |
|---|---|
| Ambient dashboard with resizable cards | `lib/home/homepage.dart` |
| Card size tiers: Small → Medium → Fullscreen → Nightstand (clock only) | `lib/home/card_layout_state.dart` |
| Nightstand mode (pitch-black + amber OLED clock) | `lib/clock/clock_card.dart`, `lib/widgets/analog_clock.dart` |
| On-device text entry without the OS keyboard | `lib/in_app_keyboard/` |
| Remote control over LAN | `lib/server/` + `assets/web/` |
| Local persistence (offline-first) | `lib/core/app_database.dart` |

---

## 2. Tech stack

- **Framework:** Flutter (Material 3, dark theme), Dart SDK `^3.13.2`.
- **State management:** `flutter_riverpod` v3 (`Notifier` / `NotifierProvider`).
- **HTTP/WebSocket host:** `shelf`, `shelf_router`, `shelf_web_socket`, `web_socket_channel`.
- **Persistence:** hand-rolled JSON file store in the app documents directory
  (`lib/core/app_database.dart`).
- **Assets:** `flutter_svg` (logo), `google_fonts` (Oswald digits on the clock).
- **Platform:** actively targets Android tablets; the standard Flutter
  `android/ ios/ linux/ macos/ windows/ web/` scaffolds exist.

### Declared vs. actually used dependencies (`pubspec.yaml`)

> ⚠️ Some dependencies are declared but **not imported anywhere in `lib/`**. Do not
> assume they are in play. Verify with a grep before relying on them.

| Package | Status |
|---|---|
| `flutter_riverpod` | Used (all state) |
| `shelf`, `shelf_router`, `shelf_web_socket`, `web_socket_channel` | Used (server + tests) |
| `path_provider` | Used (documents dir for JSON DB) |
| `flutter_svg` | Used (`header_text.svg` in `TopPillBar`) |
| `google_fonts` | Used (Oswald in the digital clocks) |
| `http` | Used only in `test/server_test.dart` |
| `sqflite`, `sqflite_common_ffi` | **Declared but unused.** Persistence is JSON, not SQLite. |
| `uuid` | **Declared but unused.** IDs are `DateTime.now().millisecondsSinceEpoch.toString()`. |
| `intl` | **Declared but unused.** Date formatting is manual. |
| `qr_flutter` | **Declared but unused.** The settings dialog shows a copyable URL, not a QR code. |
| `wakelock_plus` | **Declared but unused.** No explicit wakelock call; fullscreen is handled via `SystemChrome`. |
| `path` | Transitive helper, not directly imported. |
| `flutter_launcher_icons` | Dev tool, see §13. |
| `package_rename` | Dev tool, see §13. |

---

## 3. High-level architecture

```
┌──────────────────────────── TABLET (Flutter app, the server) ────────────────────────────┐
│                                                                                          │
│  lib/main.dart ── ProviderScope ── WyrmDeskApp                                           │
│        │  watches webServerProvider  (starts server on app boot)                         │
│        │                                                                                 │
│        ├── HomePage  (lib/home/homepage.dart)                                            │
│        │     └─ horizontal deck of cards: Clock · [Habits/Calendar] · Tasks              │
│        │           each card width animates from CardLayoutConfig                        │
│        │                                                                                 │
│        └── Riverpod providers (single in-memory source of truth)                         │
│              cardLayoutProvider · appSettingsProvider · tasksProvider                    │
│              calendarProvider · habitsProvider · localIpProvider                         │
│                    │                                ▲                                     │
│                    │ persist                        │ mutate                              │
│                    ▼                                │                                     │
│              AppDatabase  (JSON file on disk)       │                                     │
│                                                     │                                     │
│              ShelfWebServer  (lib/server/web_server.dart)                                 │
│                 • serves assets/web/*    (GET /, /style.css, /app.js, icons)              │
│                 • serves REST  /api/*                                                    │
│                 • serves WebSocket /ws  <── snapshot + state_update broadcasts            │
│                 • callbacks ────────────────┘  (onSetCardSize, onAddTask, ...)            │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                 ▲                                            │
      GET assets │ (initial load + REST fallback)              │ WS /ws + POST /api/*
                 │                                            ▼
┌────────────────────── WEB REMOTE (plain HTML/CSS/JS, assets/web/) ────────────────────────┐
│  index.html (DOM) + style.css (design tokens) + app.js                                     │
│    WyrmStateStore  ── subscribe ──▶  WyrmUiRenderer (surgical DOM updates)                 │
│    WyrmWebSocketManager  ── sends mutations, auto-reconnect every 2s ──▶  tablet           │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**Golden rule:** the web remote never owns data. It renders what the server pushes and
sends intents back. All authoritative mutation happens in Riverpod notifiers on the tablet.

---

## 4. Repository structure

```
wyrm_desk/
├── GUIDE.md                     ← you are here
├── README.md                    (default Flutter boilerplate — uninformative)
├── REFERENCE_STATE.md           ⚠️ STALE (describes SQLite/LWW/auth design that was not built)
├── docs/
│   └── web_remote_architecture.md  ⚠️ STALE (describes a Flutter-Web-compiled admin; not the current client)
├── pubspec.yaml                 deps + asset declarations
├── analysis_options.yaml        flutter_lints; analyzer excludes build/android/ios/web/windows/macos/linux
├── flutter_launcher_icons.yaml  app icon generation config
├── package_rename_release.yaml  release package/product naming ("WYRM", com.jdmakes.wyrm)
├── scripts/
│   └── build_web_admin.ps1      ⚠️ legacy build script that references a non-existent lib/web_admin_main.dart
├── assets/
│   ├── icons/                   header_text.svg, icon_bg.png, icon_fg.png, icon_flat.png
│   └── web/                     ★ the web remote, served verbatim by the Shelf server
│       ├── index.html           markup + inline SVG icons + window.wyrmRemote onclick hooks
│       ├── style.css            design token system + all styling (~1400 lines)
│       ├── app.js               ES6 store + WS manager + DOM renderer (~1366 lines)
│       └── icon_flat.png        favicon / apple-touch-icon
├── lib/
│   ├── main.dart                app entrypoint; eagerly watches webServerProvider
│   ├── core/
│   │   ├── core.dart            barrel export
│   │   ├── theme.dart           AppColors, BentoPalette ThemeExtension, AppTheme
│   │   └── app_database.dart    unified JSON persistence + legacy migration
│   ├── home/
│   │   ├── home.dart            barrel
│   │   ├── homepage.dart        the dashboard + deck layout engine
│   │   └── card_layout_state.dart  CardSize, DashboardCardType, layout config/notifier, scroll requests
│   ├── server/
│   │   ├── server.dart          barrel
│   │   ├── web_server.dart      ShelfWebServer — REST routes, WS protocol, asset serving
│   │   ├── server_provider.dart webServerProvider — wires Riverpod ⇄ server, auto-start, broadcast
│   │   └── network_info.dart    LAN IPv4 discovery + localIpProvider
│   ├── clock/
│   │   ├── clock.dart           barrel
│   │   ├── clock_card.dart      ClockContainer (sizes incl. nightstand)
│   │   └── clock_provider.dart  granular time/digit/angle providers
│   ├── habits/
│   │   ├── habits.dart          barrel
│   │   ├── habit_model.dart     HabitItem, HabitType, HeatmapCellData + streak/heatmap math
│   │   ├── habits_state.dart    HabitsState + Notifier
│   │   ├── habits_card.dart     HabitsCard (carousel Small, grid Medium/Full + heatmap)
│   │   └── habit_form_content.dart
│   ├── calendar/
│   │   ├── calendar.dart        barrel
│   │   ├── calendar_model.dart  CalendarMilestone
│   │   ├── calendar_state.dart  CalendarState (progress metrics) + Notifier
│   │   ├── calendar_card.dart   CalendarCard (Small + dual-pane Medium/Fullscreen)
│   │   └── milestone_form_content.dart
│   ├── tasks/
│   │   ├── tasks.dart           barrel
│   │   ├── task_model.dart      TaskItem
│   │   ├── tasks_state.dart     Notifier<List<TaskItem>>
│   │   ├── tasks_card.dart      TasksCard
│   │   └── task_form_content.dart
│   ├── settings/
│   │   ├── settings.dart        barrel
│   │   ├── settings_state.dart  AppSettingsConfig + Notifier
│   │   └── settings_dialog.dart SettingsDialog (incl. Web Remote URL card)
│   ├── in_app_keyboard/
│   │   ├── in_app_keyboard.dart barrel
│   │   ├── in_app_keyboard_controller.dart  state + insert/backspace/cursor logic
│   │   ├── in_app_keyboard_scope.dart       InheritedNotifier plumbing
│   │   ├── in_app_keyboard_text_field.dart  readOnly field that binds to the scope
│   │   ├── in_app_keyboard_widget.dart      the on-screen QWERTY/numpad
│   │   └── two_pane_keyboard_scaffold.dart  fullscreen 40/60 form+preview editor
│   └── widgets/
│       ├── widgets.dart         barrel
│       ├── bento_box.dart       rounded card container
│       ├── card_header.dart     uniform card title row (+ add + size menu)
│       ├── card_edit_button.dart  in-place size popup menu
│       ├── top_pill_bar.dart    top bar: logo, server IP pill, settings button
│       ├── analog_clock.dart    CustomPainter squircle analogue clock
│       ├── digital_clock_small.dart
│       └── digital_clock_medium.dart
└── test/                        see §14
```

**Barrel convention:** each feature folder has a `<feature>.dart` that re-exports its
public files. Import the barrel (`package:wyrm_desk/home/home.dart`) from other features,
not individual files.

---

## 5. Application bootstrap & startup sequence

1. `main()` → `runApp(ProviderScope(child: WyrmDeskApp()))`.
2. `WyrmDeskApp.build` calls `ref.watch(webServerProvider)` → this **eagerly instantiates
   and starts** the embedded server as a side effect (see §10).
3. `MaterialApp` (theme `AppTheme.darkTheme`, no debug banner) → `HomePage`.
4. `HomePage.initState` enters immersive sticky fullscreen (`SystemChrome`) and re-enters
   it on `AppLifecycleState.resumed`.
5. Each `Notifier.build()` returns a default state synchronously, then kicks off an async
   `_initializeFromDisk()` that hydrates from `AppDatabase` and reassigns `state`.
   → The UI first renders defaults, then re-renders with persisted data.
6. The server auto-starts on **port 8080** binding `InternetAddress.anyIPv4`.
7. `localIpProvider` (a `FutureProvider`) resolves the LAN IPv4 for display in the top bar
   and settings dialog.

---

## 6. Persistence layer — `lib/core/app_database.dart`

**Storage:** a single JSON file, `wyrm_database.json`, in
`getApplicationDocumentsDirectory()`. Written pretty-printed (2-space indent). All errors
are swallowed (test/sandbox friendliness), so writes can silently no-op.

**Top-level document shape:**

```jsonc
{
  "version": 1,
  "layout":   { "clock": "small", "habits": "small", "calendar": "small", "tasks": "small" },
  "settings": { "is_24_hour_format": false, "card_font_size": 14.0,
                "start_week_on_monday": false, "use_classic_modal_sheet": false },
  "tasks":    [ /* TaskItem[]   */ ],
  "habits":   [ /* HabitItem[]  */ ],
  "calendar": [ /* CalendarMilestone[] */ ]
}
```

**API (all `static`):**

| Method | Effect |
|---|---|
| `readDatabase()` | Reads the whole document; if missing/corrupt, runs `_initializeAndMigrateDatabase()`. |
| `writeDatabase(map)` | Overwrites the file. |
| `loadLayout` / `saveLayout` | Reads/writes `db['layout']` as `CardLayoutConfig`. |
| `loadSettings` / `saveSettings` | Reads/writes `db['settings']` as `AppSettingsConfig`. |
| `loadTasks` / `saveTasks` | Reads/writes `db['tasks']`. |
| `loadCalendarMilestones` / `saveCalendarMilestones` | Reads/writes `db['calendar']`. |
| `loadHabits` / `saveHabits` | Reads/writes `db['habits']`. |

**Legacy migration** (`_initializeAndMigrateDatabase`): if the unified file is absent, it
looks for older `card_layout.json` and `app_settings.json` files in the documents 
directory, imports them if present, and seeds an empty document otherwise.

**Notifier persistence pattern:** notifiers update `state` synchronously (optimistic),
then call the matching `AppDatabase.save*` without `await` (fire-and-forget) for
tasks/layout/settings; calendar and habits `await` their saves.

---

## 7. State management & providers (Riverpod)

All providers are global top-level `final`s. There is no `codegen`.

| Provider | Type | State type | Notes |
|---|---|---|---|
| `cardLayoutProvider` | `NotifierProvider<CardLayoutNotifier, CardLayoutConfig>` | per-card `CardSize` | `cycleCardSize`, `setCardSize`, `restoreDefaultLayout` |
| `cardScrollRequestProvider` | `NotifierProvider<CardScrollRequestNotifier, CardScrollRequest?>` | last scroll request | homepage `ref.listen`s it to animate the deck |
| `appSettingsProvider` | `NotifierProvider<AppSettingsNotifier, AppSettingsConfig>` | user prefs | 24h format, font size (clamped 11–22), week start, classic sheet |
| `tasksProvider` | `NotifierProvider<TasksNotifier, List<TaskItem>>` | task list | `addTask`, `toggleTask`, `deleteTask` |
| `calendarProvider` | `NotifierProvider<CalendarNotifier, CalendarState>` | selected date/month + milestones | month navigation, add/delete/pin milestones |
| `habitsProvider` | `NotifierProvider<HabitsNotifier, HabitsState>` | habits + carousel index | toggle/step completion, add/edit/delete, carousel |
| `webServerProvider` | `Provider<ShelfWebServer>` | the server | side effects on creation; see §10 |
| `localIpProvider` | `FutureProvider<String>` | LAN IPv4 string | used by top bar + settings |
| clock digit providers | `Provider.autoDispose<...>` | formatted strings/angles | in `lib/clock/clock_provider.dart` |

**Clock provider granularity** (`lib/clock/clock_provider.dart`): `clockTimeProvider` is a
1-second `StreamProvider`; `clockHoursProvider`, `clockMinutesProvider`,
`clockSecondsProvider`, `clockPeriodProvider`, `timeLeftTodayProvider`, and
`analogueAnglesProvider` derive from it so only the parts that changed rebuild.

---

## 8. Domain models

### 8.1 `TaskItem` — `lib/tasks/task_model.dart`

```dart
class TaskItem {
  final String id;            // epoch millis string
  final String title;
  final bool isCompleted;     // JSON: "is_completed" (also reads "completed")
  final String priority;      // 'normal' | 'high'  (default 'normal')
  final DateTime createdAt;   // JSON: "created_at" (also reads "createdAt")
}
```
`fromJson` is tolerant: falls back to `text` for title, coerces non-bool `is_completed` to false.

### 8.2 `HabitItem` + `HabitType` — `lib/habits/habit_model.dart`

```dart
enum HabitType { binary, numeric }   // fromString accepts 'numeric'|'counter'|'target' -> numeric, else binary

class HabitItem {
  final String id;
  final String title;
  final HabitType type;                 // JSON: "type"
  final int targetValue;                // JSON: "target_value" (aliases targetValue/target), min 1
  final String? unit;                   // e.g. "cups"
  final String iconName;                // JSON: "icon_name" (aliases iconName/icon), default 'bolt'
  final String colorHex;                // JSON: "color_hex"  (aliases colorHex/color), default '#A0D2B4'
  final Map<String,int> completions;    // { "YYYY-MM-DD": count }
  final DateTime createdAt;             // JSON: "created_at"
}
```

Key logic:
- `dateKey(DateTime)` → zero-padded `YYYY-MM-DD`; all completions are keyed this way.
- `completionCountOn(date)`, `isCompletedOn(date)` (`count >= targetValue`).
- `currentStreak()` — consecutive days within the **current month only** (resets at month
  boundary), with same-day grace (an incomplete today doesn't break a streak from yesterday).
- `bestStreak()`, `monthCompletedDaysCount()`, `weekProgress(weekStart)`.
- `getMonthlyHeatmapColumns(month, startWeekOnMonday:)` — GitHub-style 7-row columns.
- `getMonthlyCalendarWeeks(month, startWeekOnMonday:)` — 5–6 rows × 7 columns calendar matrix,
  returns `HeatmapCellData` cells (day number, isCurrentMonth/isFuture/isToday/isCompleted,
  intensity 0–1, count).
- Heatmap intensity: completed → 1.0; partial → `(count/targetValue).clamp(0.2, 0.8)`.

### 8.3 `CalendarMilestone` — `lib/calendar/calendar_model.dart`

```dart
class CalendarMilestone {
  final String id;
  final String title;        // JSON: "title" (aliases text/name)
  final DateTime targetDate; // JSON: "target_date" (aliases date/targetDate)
  final bool isPinned;       // JSON: "is_pinned" (aliases pinned/isPinned; coerces 1/'true')
  final DateTime createdAt;  // JSON: "created_at"
}
```
Helpers: `daysRemaining([ref])`, `isToday`, `isPast`, `relativeLabel`
("Today"/"Tomorrow"/"Yesterday"/"In N days"/"N weeks ago").

`CalendarState` (`lib/calendar/calendar_state.dart`) holds `selectedDate`, `viewMonth`,
`milestones`, and computes `dayOfYear`, `daysInYear`, `yearProgress`, `currentQuarter`,
`quarterProgress`, `heroMilestone` (pinned first, else nearest upcoming), `relativeDistanceText`.

### 8.4 `CardSize` + `DashboardCardType` + `CardLayoutConfig` — `lib/home/card_layout_state.dart`

```dart
enum CardSize { small, medium, fullscreen, nightstand }
//  next: small->medium->fullscreen->nightstand->small
//  label: 'Small' | 'Medium' | 'Fullscreen' | 'Nightstand'

enum DashboardCardType { clock, habits, calendar, tasks }
//  tryParse(String?) -> case-insensitive match, else null

class CardLayoutConfig { CardSize clock, habits, calendar, tasks; }  // all default small
//  sizeFor(type), withSize(type, size), toJson()/fromJson()
```
`CardLayoutConfig.toJson()` emits `{clock,habits,calendar,tasks}` using enum `.name`
strings. `fromJson` resolves unknown tokens to `small`.

### 8.5 `AppSettingsConfig` — `lib/settings/settings_state.dart`

```dart
class AppSettingsConfig {
  final bool is24HourFormat;          // JSON: "is_24_hour_format"
  final double cardFontSize;          // JSON: "card_font_size"  (default 14.0, clamped 11–22)
  final bool startWeekOnMonday;       // JSON: "start_week_on_monday"
  final bool useClassicModalSheet;    // JSON: "use_classic_modal_sheet"
}
```

> ⚠️ **Key-name mismatch to be aware of:** on-disk settings use snake_case, but the
> **server payload uses camelCase** (`is24HourFormat`, `cardFontSize`, `startWeekOnMonday`).
> The web client and server both speak camelCase. Only the DB file uses snake_case.

---

## 9. Dashboard layout engine — `lib/home/homepage.dart`

`HomePage` is a horizontal, single-axis scroll deck. Card widths are computed from the
`CardLayoutConfig` and the viewport width, then animated (380 ms, `easeInOutCubic`).

- **Top bar** (`TopPillBar`, height 54) collapses to height 0 in Nightstand mode.
- **Padding** collapses to `EdgeInsets.zero` in Nightstand mode.
- **Scroll request** from the remote is handled via `ref.listen(cardScrollRequestProvider)`
  → `Scrollable.ensureVisible` on the card's `GlobalKey` (with a 400 ms re-align pass).

**Width rules** (`_buildScrollableDeck`):

| Card | small | medium | fullscreen | nightstand |
|---|---|---|---|---|
| clock | 280 (or `(w-2*spacing)*3/14` when all-small & `w>1140`) | `clamp(w*0.5, 380, 900)` | `w` | `w` |
| habits | 340 | `clamp(w*0.5, 380, 900)` | `w` | n/a |
| calendar | 420 | `clamp(w*0.5, 380, 900)` | `w` | n/a |
| tasks | 320 (or `(w-2*spacing)*4/14` when all-small & `w>1140`) | `clamp(w*0.5, 380, 900)` | `w` | n/a |

**Center stacking:** when **both** `habits` and `calendar` are `small`, they stack vertically
in one column (width 520, or `(w-2*spacing)*7/14` when all-small & `w>1140`); otherwise each
becomes its own independent column.

`CardSize.nightstand` is only meaningful for the clock; it forces a pitch-black canvas with
glowing amber analogue + digital clock (`_ClockFullscreenView(isNightstand: true)`).

---

## 10. Embedded server — `lib/server/`

### 10.1 `ShelfWebServer` (`web_server.dart`)

Constructed with **getter callbacks** (read current state) and **mutation callbacks**
(apply changes). Optional `htmlOverride`/`cssOverride`/`jsOverride`/`faviconOverride`
strings/bytes exist purely for headless tests (so tests don't need Flutter asset bundles).

Lifecycle: `start({port = 8080})` binds `InternetAddress.anyIPv4`; `stop()` closes all WS
clients and the server; `isRunning`, `port`, `connectedClientsCount` expose status.

**Callback contract** (all injected by `server_provider.dart`):

```
getLayoutConfig() / getSettingsConfig() / getTasksConfig() / getCalendarConfig() / getHabitsConfig()
onSetCardSize(type, size)          onSet24HourFormat(bool)        onSetCardFontSize(double)
onSetStartWeekOnMonday(bool)
onAddTask(title, priority)         onToggleTask(id)               onDeleteTask(id)
onAddMilestone(title, date, {isPinned})  onDeleteMilestone(id)    onTogglePinMilestone(id)
onAddHabit(title, type, target, {unit, iconName})
onToggleHabit(id, [date])          onStepHabit(id, delta, [date]) onDeleteHabit(id)
onScrollToCard(card)
```

> `_applyCardSize(card, size)` resolves names case-insensitively and, **after resizing, also
> triggers `onScrollToCard`** so the tablet scrolls the resized card into view.

### 10.2 `webServerProvider` (`server_provider.dart`)

One `Provider<ShelfWebServer>` that:
1. Builds the server with all callbacks delegating to the Riverpod notifiers.
2. **Auto-starts** it (`server.start()`), swallowing port-conflict errors.
3. Registers `ref.listen` on `cardLayoutProvider`, `appSettingsProvider`, `tasksProvider`,
   `calendarProvider`, `habitsProvider` → each change calls `server.broadcastState(...)`.
   **This is how tablet-originated changes reach the web remote.**
4. `ref.onDispose` stops the server.

### 10.3 Network discovery (`network_info.dart`)

`NetworkInfo.getLocalIpAddress()` lists IPv4 interfaces, prefers wifi/eth-like names,
falls back to any non-loopback, and finally `127.0.0.1`. Exposed via `localIpProvider`.
The top bar and settings dialog render `http://<ip>:8080`.

---

## 11. Server API — routes, REST, and WebSocket protocol

### 11.1 Static asset routes (served from `assets/web/` / `assets/icons/`)

| Route | Content-Type | Serves |
|---|---|---|
| `GET /` and `GET /index.html` | `text/html; charset=utf-8` | `assets/web/index.html` |
| `GET /style.css` | `text/css; charset=utf-8` | `assets/web/style.css` |
| `GET /app.js` | `application/javascript; charset=utf-8` | `assets/web/app.js` |
| `GET /favicon.ico`, `/icon_flat.png`, `/assets/icons/icon_flat.png` | `image/png` | `assets/icons/icon_flat.png` |

CSS/JS/HTML are served with `Cache-Control: no-cache` (bump `?v=` in `index.html` when you
change them). `index.html` references `style.css?v=2` and `app.js?v=2`.

### 11.2 REST endpoints (all under `http://<ip>:8080/api`)

| Method | Endpoint | Body (JSON) | Effect |
|---|---|---|---|
| `GET` | `/api/status` | — | `{status:'online', layout, settings, tasks, calendar}`. **Note: no `habits`.** |
| `POST` | `/api/layout` | `{card, size}` | `onSetCardSize` (+ scroll) |
| `POST` | `/api/scroll` | `{card}` | `onScrollToCard`; 400 on unknown card |
| `POST` | `/api/settings` | any of `is24HourFormat`, `cardFontSize`, `startWeekOnMonday` | applies present keys |
| `GET` | `/api/tasks` | — | `TaskItem[]` |
| `POST` | `/api/tasks` | `{title|text, priority?}` | add task |
| `POST` | `/api/tasks/toggle` | `{id}` | toggle completion |
| `POST` | `/api/tasks/delete` | `{id}` | delete |
| `GET` | `/api/calendar` | — | serialized calendar state + milestones |
| `POST` | `/api/calendar/milestones` | `{title|text|name, target_date|targetDate|date, is_pinned?}` | add milestone |
| `POST` | `/api/calendar/milestones/delete` | `{id}` | delete |
| `POST` | `/api/calendar/milestones/pin` | `{id}` | toggle pin |
| `GET` | `/api/habits` | — | `HabitItem[]` |
| `POST` | `/api/habits` | `{title|name, habit_type|type, target_value|targetValue|target, unit?, icon_name|iconName|glyph?}` | add habit |
| `POST` | `/api/habits/toggle` | `{id, date?}` | toggle completion for date |
| `POST` | `/api/habits/step` | `{id, delta, date?}` | step numeric count |
| `POST` | `/api/habits/delete` | `{id}` | delete |

**Date parsing:** milestone dates accept ISO (`yyyy-mm-dd`, parsed by `DateTime.tryParse`)
or `dd/mm/yyyy` (see `_parseMilestoneDate`). Empty/invalid → `DateTime.now()`. Habit
completion dates accept ISO via `DateTime.tryParse`.

**Error convention:** invalid/empty payloads → `400` with `{"error": "..."}`. Success →
`{"success": true}` (scroll also returns `{"card": <name>}`).

### 11.3 WebSocket — `GET /ws`

On connect the server sends a **`snapshot`** message. Every state change on the tablet is
broadcast as a **`state_update`** to all connected clients (both have the same shape):

```jsonc
{
  "type": "snapshot" | "state_update",
  "layout":   { "clock": "small", "habits": "medium", "calendar": "small", "tasks": "fullscreen" },
  "settings": { "is24HourFormat": false, "cardFontSize": 14.0, "startWeekOnMonday": false },
  "tasks":    [ { "id","title","is_completed","priority","created_at" } ],
  "calendar": {
      "today","selectedDate","viewMonth",
      "yearProgress","quarterProgress","dayOfYear","daysInYear","currentQuarter",
      "startWeekOnMonday","milestones":[ { "id","title","target_date","is_pinned","created_at" } ]
  },
  "habits":   [ { "id","title","type","target_value","unit","icon_name","color_hex","completions","created_at" } ]
}
```

**Client → server message types** (JSON, first field `type`):

| `type` | Additional fields | Maps to |
|---|---|---|
| `set_layout` | `card`, `size` | `_applyCardSize` (resize + scroll) |
| `set_settings` | any of `is24HourFormat`, `cardFontSize`, `startWeekOnMonday` | settings notifier |
| `create_task` | `title`, `priority?` | `onAddTask` |
| `toggle_task` | `id` | `onToggleTask` |
| `delete_task` | `id` | `onDeleteTask` |
| `create_milestone` | `title`, `target_date`/`targetDate`/`date`, `is_pinned?`/`isPinned?` | `onAddMilestone` |
| `delete_milestone` | `id` | `onDeleteMilestone` |
| `toggle_pin_milestone` | `id` | `onTogglePinMilestone` |
| `create_habit` | `title`/`name`, `habit_type`/`type`, `target_value`, `unit?`, `icon_name`/`iconName`/`glyph?` | `onAddHabit` |
| `toggle_habit` | `id`, `date?` | `onToggleHabit` |
| `step_habit` | `id`, `delta`, `date?` | `onStepHabit` |
| `delete_habit` | `id` | `onDeleteHabit` |
| `scroll_to_card` | `card` | `onScrollToCard` |

Unknown types and malformed JSON are ignored (the listener wraps everything in try/catch).
The server never sends acknowledgements; clients learn the result from the next broadcast.

---

## 12. Web remote client — `assets/web/`

Three hand-written files, no build step, no framework. Served verbatim by the Shelf server.

### 12.1 `index.html` — structure

- **Meta:** viewport locked (no zoom), dual `theme-color` (dark `#0a0b0e` / light `#f2f2f7`),
  iOS standalone PWA meta, apple-touch-icon, favicon → `/assets/icons/icon_flat.png`.
- **Header (`glass-panel`)**: `header-brand` (inline SVG WYRM wordmark), a center
  `page-switcher` with tabs **Layout / Clock / Habits / Calendar / Tasks**, a
  `themeToggleBtn` (cycle auto→dark→light) and a `networkBadge` (`pulse-dot` + label
  showing `CONNECTING...` or `LIVE`).
- **Card stream (`#mainContent`)**: `article.layout-card` elements, each with
  `data-card="clock|habits|calendar|tasks|all"`. Response-card sizing uses
  `.segmented-bar > .segment-btn`; detail/view-only cards use the `detail-card` and
  `card-detail-section` classes (hidden unless their tab is active).
- **Feature sections present:** All-cards controller, Clock + 24-hour toggle,
  Habits + habit tracker (`habitGlyphPicker`, `habitsList`), Calendar + week-start toggle +
  progress bars + interactive web calendar grid (`webCalDays`) + milestones manager
  (`milestoneDateInput`, `milestoneNativePicker`, `milestonesList`), Tasks + font-size
  stepper + tasks checklist (`taskInput`, `taskPriority`, `tasksList`).
- **Mobile bottom tab bar (`mobile-tab-bar glass-panel`)**: the same 5 tabs for thumb reach.
- **Interaction model:** every control calls `window.wyrmRemote.<method>()` via inline
  `onclick`/`onkeydown`; no framework binding.

### 12.2 `style.css` — design system

Documented token block at the top (Apple HIG + Dieter Rams "Liquid Glass"). Key tokens:

```
--bg-canvas:#0a0b0e  --bg-surface:#14171f  --bg-surface-elevated:#1a1e28
--glass-bg:rgba(18,20,27,.78)  --glass-blur:blur(28px) saturate(190%)
--border-subtle / --border-hover / --border-focus / --border-amber
--accent-amber:#ff9500  --accent-green:#34c759  --accent-red:#ff3b30
--text-primary / --text-secondary / --text-muted / --text-inverse
--font-sans (SF Pro/Inter)  --font-mono (SF Mono)  --ease-spring
--safe-top/bottom/left/right: env(safe-area-inset-*)
```

- **Three appearance states:** default dark, `@media (prefers-color-scheme: light)`, and
  explicit `[data-theme="light"|"dark"]` overrides (set by `app.js`).
- Sticky frosted headers use `backdrop-filter`.
- Layout is a single-column card stream on phones; the header nav appears on wider screens
  (the bottom tab bar is the mobile affordance).
- `body[data-active-page]` scopes per-tab visibility in addition to the JS display toggling.

### 12.3 `app.js` — engine (~1366 lines)

Four pieces:

1. **`WyrmHaptics`** — wraps `navigator.vibrate` (`tap/selection/success/impact`) with try/catch.
2. **`WyrmStateStore`** — the client mirror of state:
   ```js
   { layout:{clock,habits,calendar,tasks}, settings:{is24HourFormat,cardFontSize,startWeekOnMonday},
     tasks:[], habits:[], calendar:{...}, activeFilter:'all', isConnected:false, theme:'auto'|'dark'|'light' }
   ```
   `subscribe(fn)` (observer), `setState(partial)` (shallow merge with nested merge for
   `layout`/`settings`/`calendar`), `getState()`. Theme persists in
   `localStorage('wyrm_theme')`.
3. **`WyrmWebSocketManager`** — connects to `${ws|wss}://location.host/ws`, auto-reconnects
   every 2 s, marks `isConnected`. Each mutation method **prefers WS** and **falls back to
   the matching REST POST** if the socket isn't open. Incoming `snapshot`/`state_update`
   messages are merged into the store.
4. **`WyrmUiRenderer`** — caches DOM refs, owns all handlers, and surgically re-renders:
   `render()` calls `_renderNetworkStatus`, `_renderPageSwitcher`, `_renderCards`,
   `_render24HourToggle`, `_renderFontSize`, `_renderTasks`, `_renderCalendar`
   (→ web calendar + milestones), `_renderHabits`.

**Bootstrap (`DOMContentLoaded`):** build store → ws manager → renderer → expose
`window.wyrmRemote` (the full command surface, listed below) → `store.subscribe(render)` →
**initial REST sync** via `fetch('/api/status')` → `wsManager.connect()`.

**Theme:** `cycleTheme()` steps `dark ⟷ light` (never returns to `auto` once clicked) and
sets `document.documentElement[data-theme]`.

**`window.wyrmRemote` surface:**
`setCardSize`, `setAllCardsSize`, `toggleTimeFormat`, `incrementFontSize`, `decrementFontSize`,
`setCardFilter`, `cycleTheme`, `addTask`, `toggleTask`, `deleteTask`, `toggleStartWeekOnMonday`,
`prevWebMonth`, `nextWebMonth`, `todayWebMonth`, `promptTravelDate`, `travelWebDate`,
`selectWebDate`, `addMilestone`, `createMilestone`, `deleteMilestone`, `togglePinMilestone`,
`pickMilestoneDate`, `onMilestonePickerChange`, `onHabitTypeChange`, `selectHabitGlyph`,
`addHabit`, `toggleHabit`, `stepHabit`, `deleteHabit`, `scrollToCard`.

**Notable behaviors:**
- Tab filter (`activeFilter`) hides `detail-card`s in "Layout" view and shows only matching
  `data-card` sections otherwise.
- Tapping a card body (outside interactive controls) sends `scroll_to_card`.
- Resizing sends `set_layout`; global layout buttons send one `set_layout` per card and mark
  the "All Cards" badge `MIXED` when sizes differ.
- Habitat glyphs and habit icons are inline SVG maps (`_resolveGlyphEmoji`).
- Milestone date field enforces `dd/mm/yyyy` with auto-slash insertion and a native picker bridge.
- Habit "today" is computed from `new Date().toISOString().split('T')[0]` (**UTC**), while the
  tablet uses local `dateKey`. Watch this on non-UTC hosts.

---

## 13. Features (deep dive)

### Clock (`lib/clock`, `lib/widgets`)
- `ClockContainer` renders per size: `DigitalClockSmall` (vertical), `DigitalClockMedium`
  (horizontal, Oswald font), `_ClockFullscreenView` (squircle analogue + horizontal digital),
  and nightstand (same fullscreen view, black + amber). Header is hidden in nightstand.
- Analogue face is a `CustomPainter` (`analog_clock.dart`) with discrete stepping hands.

### Habits (`lib/habits`)
- **Small:** one-habit carousel (`cycleCarousel`), streak capsule, numeric stepper or binary
  toggle, and a tappable 7-day week strip.
- **Medium/Fullscreen:** grid of habit tiles (1 col medium, 2 col fullscreen), each with
  today action, week strip, and a GitHub/calendar-style monthly heatmap.
- **Creation/edit:** `TwoPaneKeyboardScaffold` (default) or classic bottom sheet (setting),
  using `HabitFormContent` + `HabitPreviewTile`; icon picker, binary/numeric type, target, unit.

### Calendar (`lib/calendar`)
- **Small:** dynamic banner (Today vs. selected + relative distance), month nav
  (Today/Travel/prev/next), 7-column grid with milestone dots, and a hero milestone ticker.
- **Medium/Fullscreen:** dual-pane — left month grid, right "temporal inspector" with selected
  day hero, Year & Quarter progress bars, and the milestone list (pin/delete).
- `heroMilestone` logic and `relativeDistanceText` live in `CalendarState`.

### Tasks (`lib/tasks`)
- Single scrollable checklist used in all sizes; strikethrough on complete, `HIGH` badge,
  per-item delete. Orange card.
- **Creation:** `TwoPaneKeyboardScaffold` (default) or classic bottom sheet, with
  `TaskFormContent` + `TaskPreviewCard`.
- Font size for task/habit text comes from `AppSettingsConfig.cardFontSize` (11–22 pt).

### In-app keyboard (`lib/in_app_keyboard`)
Non-OS on-screen keyboard for a device that shouldn't summon the system IME.
- `InAppKeyboardController` (a `ChangeNotifier`) tracks the active `TextEditingController`,
  mode (`letters`/`symbols`/`numpad`), shift/caps, and implements insert/backspace/clear/
  cursor-move/submit.
- `InAppKeyboardScope` is an `InheritedNotifier` distributing the controller.
- `InAppKeyboardTextField` becomes `readOnly` when a scope is present (so it binds to the
  in-app keyboard) and normal otherwise.
- `TwoPaneKeyboardScaffold` lays out form (40% / flex 4) on the left and live preview +
  keyboard (60% / flex 6) on the right; narrow screens (< 720 px) stack vertically.
- Toggle between this editor and the classic modal sheet via `useClassicModalSheet`.

### Settings (`lib/settings`)
`SettingsDialog.show(context)` (from the top bar gear) exposes: 24-hour time, card text size
stepper (11–22 pt), start-week-on-Monday, classic-modal-sheet toggle, and a **Web Remote**
card showing/copying `http://<ip>:8080`.

---

## 14. Testing

`test/` is a widget + unit + integration suite (`flutter_test`). Run with
`flutter test` (all) or `flutter test test/<file>`.

| File | Focus |
|---|---|
| `server_test.dart` | Starts a real `ShelfWebServer` on an ephemeral port with asset overrides; covers every static route, REST endpoint, the WS snapshot + command protocol, `NetworkInfo`, and asserts the `assets/web/*` files contain required tokens. **Update this when you change routes/messages or DOM ids/classes.** |
| `widget_test.dart` | App-level smoke tests (default Flutter file, adapted). |
| `home_page_test.dart` | Dashboard deck layout / sizing. |
| `clock_card_test.dart` | Clock sizes + nightstand + providers/angles. |
| `habits_test.dart` | Habit model math (streaks, heatmaps, weeks) + card layouts. |
| `calendar_test.dart` | Milestone (de)serialization, progress metrics, Small/Medium layouts, travel picker. |
| `tasks_test.dart` | Task model tolerance + card rendering. |
| `two_pane_editor_test.dart` | Settings toggle, 40/60 split, form+preview widgets, cards opening the editor. |
| `in_app_keyboard_test.dart` | Keyboard controller logic + scoped text field readOnly behavior. |

**Conventions used in tests:** `ProviderScope` with overridden providers; a `TestWidgetsFlutterBinding`;
`htmlOverride/cssOverride/jsOverride/faviconOverride` to avoid asset-bundle dependence;
`IOWebSocketChannel.connect` for live WS tests.

---

## 15. Design system

### Flutter palette (`lib/core/theme.dart`)

```
background #000000   surface #121418   surfaceElevated #1B1E26   borderDark #222631
cardSage #A0D2B4   cardYellow #FEE15F   cardCream #FCF7CB   cardOrange #E06E3F   cardWhite #FFFFFF
accentOrange #FF7F00   accentRed #FF3B30
textPrimary #FFFFFF   textSecondary #8E95A5   textMuted #535868   textOnLight #111111
```
`BentoPalette` is a `ThemeExtension` exposing the card colors via `context.bento`.
Card accent mapping: Clock = white, Habits = sage, Calendar = yellow, Tasks = orange,
Top bar = cream. Nightstand accent = `#FF9500` amber (defined inline in clock widgets).

### Web palette (`assets/web/style.css`)

Obsidian + amber "Liquid Glass" (see §12.2). Amber `#ff9500` is the signature brand signal.
The web palette and Flutter palette are intentionally *different* systems — do not try to
unify them blindly.

### Typography
- Flutter UI: default Material text; clock digits use **Oswald** (google_fonts).
- Web: `--font-sans` (SF Pro/Inter stack) and `--font-mono` for diagnostics.

---

## 16. Commands

```powershell
# Run on a device/emulator (server auto-starts on :8080)
flutter run

# Analyze / lint (analyzer excludes platform dirs + build)
flutter analyze

# All tests / a single file
flutter test
flutter test test/server_test.dart

# Regenerate app icons (uses flutter_launcher_icons.yaml)
dart run flutter_launcher_icons

# Apply release naming across platforms (uses package_rename_release.yaml)
dart run package_rename
```

**Asset registration:** new assets must be added under `flutter: assets:` in `pubspec.yaml`.
Currently registered: `assets/icons/` and `assets/web/`.

**Web remote edits require no build step** — `assets/web/*` is served directly. Bump the
`?v=` query in `index.html` (for `style.css`/`app.js`) to defeat client caching, and update
the asset-token assertions in `server_test.dart` if you rename ids/classes.

> `scripts/build_web_admin.ps1` is **legacy and broken**: it runs
> `flutter build web -t lib/web_admin_main.dart` for a file that does not exist. The current
> web remote is hand-written, not Flutter-compiled. Do not run it as-is.

---

## 17. Known discrepancies & stale docs

| Artifact | Problem |
|---|---|
| `REFERENCE_STATE.md` | Describes SQLite schema, LWW sync, PIN `/api/auth/login`, `/api/sync`, `retro_colors.dart` — **none of which exist**. Current storage is a single JSON file; there is no auth. |
| `docs/web_remote_architecture.md` | Describes a Flutter-Web admin, a latency heartbeat, `fetch('/api/status')` ping, and different endpoints/ids. The current client is plain HTML/CSS/JS with a simpler `LIVE`/`CONNECTING` badge and no ping. |
| `scripts/build_web_admin.ps1` | References a nonexistent `lib/web_admin_main.dart`. |
| `pubspec.yaml` | `sqflite`, `sqflite_common_ffi`, `uuid`, `intl`, `qr_flutter`, `wakelock_plus` are declared but unused in `lib/`. |
| `/api/status` | Returns `layout/settings/tasks/calendar` but **omits `habits`**, so a REST-only initial load starts with an empty habit list until the WS snapshot arrives. Candidate bug. |
| Habit "today" | Web client computes today via UTC `toISOString()`; tablet uses local `dateKey()`. Divergence near midnight / non-UTC. |
| `README.md` | Untouched Flutter boilerplate. |

---

## 18. Conventions & how to work here

### Code style
- Dart: `flutter_lints`; use `const` where possible, doc-comment (`///`) public members,
  private helpers prefixed `_`, and match the existing "explain each public field" style.
- Keep card widgets as `ConsumerWidget`/`ConsumerStatefulWidget`; read state with
  `ref.watch`, mutate with `ref.read(provider.notifier)`.
- Persist via `AppDatabase.save*` right after state mutation, mirroring existing patterns.
- Web: vanilla ES6, no frameworks, no bundler. Add inline `onclick="window.wyrmRemote.x()"`
  hooks to `index.html`, implement handlers on `WyrmUiRenderer`, and register them on
  `window.wyrmRemote` in the bootstrap block.

### Adding a new card size option
1. Extend the relevant enum in `lib/home/card_layout_state.dart` (and its `next`/`label`).
2. Handle it in `homepage.dart` width logic.
3. Add the segmented button + `data-card` handling in `assets/web/index.html`/`app.js`.
4. Update `test/server_test.dart` asset assertions if ids change.

### Adding a new remote-controlled feature (end-to-end)
1. Add the model/state in its feature folder under `lib/`.
2. Add a mutation callback + route/message type in `lib/server/web_server.dart`.
3. Wire the callback in `lib/server/server_provider.dart` and add a `ref.listen` broadcast.
4. Add JSON to the snapshot/broadcast payload and to `/api/status` if the client needs it.
5. Add the UI + `window.wyrmRemote` command in `assets/web/*`.
6. Extend `test/server_test.dart` (REST + WS) and any feature test.

### Things to be careful about
- **Never break the snapshot/broadcast payload shape** without updating `app.js`
  (`_handleIncomingMessage` and the renderers) and the WS test.
- The `state` broadcast is built from `getLayoutConfig()`/`getSettingsConfig()`/etc. getters,
  so new state must be reachable through those getters.
- `_applyCardSize` implicitly scrolls; don't double-scroll in callers.
- Settings have **camelCase on the wire, snake_case on disk**.

---

## 19. Quick reference

- **Default port:** `8080` (`ShelfWebServer.defaultPort`), bound to `anyIPv4`.
- **WebSocket path:** `/ws`.
- **Persisted file:** `<appDocuments>/wyrm_database.json`.
- **Asset roots:** `assets/icons/`, `assets/web/`.
- **Remote URL format:** `http://<lan-ip>:8080`.
- **Card sizes:** `small`, `medium`, `fullscreen`, `nightstand` (clock only).
- **Card ids / `data-card`:** `clock`, `habits`, `calendar`, `tasks` (+ `all` pseudo-card).
- **Settings keys (wire):** `is24HourFormat`, `cardFontSize`, `startWeekOnMonday`.
- **Settings keys (disk):** `is_24_hour_format`, `card_font_size`, `start_week_on_monday`,
  `use_classic_modal_sheet`.
- **Habit icon tokens:** `bolt`, `water_drop`, `fitness_center`, `menu_book`,
  `directions_run`, `bedtime`, `wb_sunny`, `code`, `local_cafe`, `check_circle`, `favorite`.
