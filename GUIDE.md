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
| Ambient dashboard with resizable cards | `lib/features/home/homepage.dart` |
| Card size tiers: Small → Medium → Fullscreen → Nightstand (clock only) | `lib/config/card_layout_state.dart` |
| Nightstand mode (pitch-black + amber OLED clock) | `lib/features/clock/clock_card.dart`, `lib/features/clock/clock_face_analog.dart` |
| On-device text entry without the OS keyboard | `lib/features/keyboard/` |
| Remote control over LAN | `lib/server/` + per-feature `*_server_section.dart` + `assets/web/` |
| Local persistence (offline-first) | `lib/data/app_database.dart` |

---

## 2. Tech stack

- **Framework:** Flutter (Material 3, dark theme), Dart SDK `^3.14.0`.
- **UI kit:** `material_ui` (the app's base import for Flutter widgets/design primitives).
- **State management:** `flutter_riverpod` v3 (`Notifier` / `NotifierProvider`).
- **HTTP/WebSocket host:** `shelf`, `shelf_router`, `shelf_web_socket`, `web_socket_channel`.
- **Persistence:** hand-rolled JSON file store in the app documents directory
  (`lib/data/app_database.dart`) with a whole-document backup engine.
- **Assets:** `flutter_svg` (logo), `google_fonts` (Barlow Condensed digits on the clock),
  `qr_flutter` (web-remote QR code in the network modal), `intl` (date formatting in the
  calendar card and milestone form).
- **Platform:** actively targets Android tablets; the standard Flutter
  `android/ ios/ linux/ macos/ windows/ web/` scaffolds exist.

### Declared vs. actually used dependencies (`pubspec.yaml`)

> ⚠️ Some dependencies are declared but **not imported anywhere in `lib/`**. Do not
> assume they are in play. Verify with a grep before relying on them.

| Package | Status |
|---|---|
| `material_ui` | Used (base UI import across all of `lib/`) |
| `flutter_riverpod` | Used (all state) |
| `shelf`, `shelf_router`, `shelf_web_socket`, `web_socket_channel` | Used (server + tests) |
| `path_provider` | Used (documents dir for JSON DB + Downloads backup) |
| `flutter_svg` | Used (`header_text.svg` in `TopPillBar`) |
| `google_fonts` | Used (Barlow Condensed in the digital clocks) |
| `qr_flutter` | Used (`QrImageView` in the network connection modal) |
| `intl` | Used (`DateFormat` in the calendar card and milestone form) |
| `http` | Used only in `test/server/server_test.dart` |
| `wakelock_plus` | **Declared but unused.** Fullscreen is handled via `SystemChrome`. |
| `qr` | Transitive of `qr_flutter`; not directly imported. |
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
│        ├── HomePage  (lib/features/home/homepage.dart)                                   │
│        │     └─ horizontal deck of cards: Clock · [Habits/Calendar] · Tasks              │
│        │           each card width animates from CardLayoutConfig                        │
│        │                                                                                 │
│        └── Riverpod providers (single in-memory source of truth)                         │
│              cardLayoutProvider · appSettingsProvider · tasksProvider                    │
│              calendarProvider · habitsProvider · displayProvider · localIpProvider       │
│                    │                                ▲                                     │
│                    │ persist                        │ mutate                              │
│                    ▼                                │                                     │
│              AppDatabase  (JSON file on disk,       │                                     │
│                             lib/data/app_database.dart)                                   │
│                                                     │                                     │
│              ShelfWebServer  (lib/server/web_server.dart — transport only)                │
│                 • serves assets/web/*    (GET /, /style.css, /app.js, icons)              │
│                 • serves REST  /api/*    (routes owned by per-feature ServerSections)     │
│                 • serves WebSocket /ws  <── snapshot + state_update broadcasts            │
│                 • sections ────────────────┘  (each feature registers routes + handlers)  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
                 ▲                                            │
      GET assets │ (initial load + REST fallback)              │ WS /ws + POST /api/*
                 │                                            ▼
┌────────────────────── WEB REMOTE (Vue 3 app, assets/web/) ────────────────────────────────┐
│  index.html + style.css (design tokens) + components.js + app.js (+ vue.global.prod.js)   │
│    WyrmStateStore  ── reactivity ──▶  Vue components (surgical DOM updates)                │
│    WyrmWebSocketManager  ── sends mutations, auto-reconnect ──▶  tablet                   │
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
├── assets/
│   ├── icons/                   header_text.svg, icon_bg.png, icon_fg.png, icon_flat.png
│   └── web/                     ★ the web remote, served verbatim by the Shelf server
│       ├── index.html           markup + Vue directives + window.wyrmRemote onclick hooks
│       ├── style.css            design token system + all styling
│       ├── app.js               Vue 3 store + WS manager + renderer
│       ├── components.js        Vue component definitions
│       ├── vue.global.prod.js   offline Vue 3 runtime bundle
│       ├── manifest.webmanifest PWA manifest
│       └── icon_flat.png        favicon / apple-touch-icon
├── lib/
│   ├── main.dart                app entrypoint; eagerly watches webServerProvider
│   ├── config/                  cross-feature shared config (consumed by every card)
│   │   ├── app_settings_state.dart   AppSettingsConfig + Notifier + persistence
│   │   ├── card_layout_state.dart    CardSize, DashboardCardType, layout config/notifier,
│   │   │                             scroll requests, cardSizeMenuOptions()
│   │   ├── layout_server_section.dart   layout/scroll ServerSection
│   │   └── settings_server_section.dart settings ServerSection
│   ├── core/
│   │   └── date_names.dart      month-name lookup (pure Dart, no Flutter)
│   ├── data/
│   │   ├── app_database.dart    feature-agnostic keyed-section JSON store + backup engine
│   │   └── database_service.dart  DatabaseService: reload-on-import orchestration
│   ├── features/                ★ feature-first; each folder reads end-to-end
│   │   ├── calendar/
│   │   │   ├── calendar_model.dart            CalendarMilestone
│   │   │   ├── calendar_state.dart            CalendarState + Notifier + persistence
│   │   │   ├── calendar_card.dart             CalendarCard (Small + dual-pane Medium/Full)
│   │   │   ├── calendar_server_section.dart   /api/calendar + WS commands + snapshot slice
│   │   │   └── milestone_form_content.dart    MilestoneFormContent + MilestonePreviewCard
│   │   ├── clock/                   the drifting day-photograph card
│   │   │   ├── clock_card.dart               ClockContainer: tiers + frame
│   │   │   ├── clock_fullscreen_view.dart    analogue + digital companion
│   │   │   ├── clock_face_analog.dart        smoked-glass squircle dial (CustomPainter)
│   │   │   ├── clock_face_digital_small.dart
│   │   │   ├── clock_face_digital_medium.dart
│   │   │   ├── clock_date_line.dart           date readout (top of every tier)
│   │   │   ├── clock_sun_countdown.dart       hours left today (bottom-left of every tier)
│   │   │   ├── clock_numeral.dart            the one display-type spec
│   │   │   ├── clock_palette.dart            ClockTone: slate / nightstand
│   │   │   ├── clock_backdrop.dart           drifting photo backdrop
│   │   │   ├── clock_backdrop_motion.dart    drift step + interval (the tune point)
│   │   │   └── clock_provider.dart           time, digits, angles, day photo
│   │   ├── display/
│   │   │   ├── display_state.dart            DisplayState + Notifier (brightness)
│   │   │   ├── display_service.dart          system brightness bridge
│   │   │   └── display_server_section.dart   /api/display + set_display + snapshot slice
│   │   ├── habits/
│   │   │   ├── habit_model.dart               HabitItem, HabitType, HeatmapCellData + math
│   │   │   ├── habits_state.dart              HabitsState + Notifier + persistence
│   │   │   ├── habits_card.dart               HabitsCard (carousel Small, grid Medium/Full)
│   │   │   ├── habits_server_section.dart     /api/habits + WS commands + snapshot slice
│   │   │   └── habit_form_content.dart        HabitFormContent + HabitPreviewTile + glyph map
│   │   ├── home/
│   │   │   ├── homepage.dart      the dashboard + deck layout engine (shell exception:
│   │   │   │                      allowed to import every card feature)
│   │   │   └── top_pill_bar.dart  top bar: logo, server IP pill, settings button
│   │   ├── keyboard/              shared form editor used by tasks/habits/calendar
│   │   │   ├── in_app_keyboard_controller.dart  state + insert/backspace/cursor logic
│   │   │   ├── in_app_keyboard_scope.dart       InheritedNotifier plumbing
│   │   │   ├── in_app_keyboard_text_field.dart  readOnly field that binds to the scope
│   │   │   ├── in_app_keyboard_widget.dart      the on-screen QWERTY/symbols/numpad
│   │   │   └── two_pane_keyboard_scaffold.dart  fullscreen 40/60 form+preview editor
│   │   ├── network/
│   │   │   ├── network_info.dart             LAN IPv4 discovery + localIpProvider
│   │   │   ├── network_modal.dart            NetworkConnectionModal (URL + QR code)
│   │   │   └── network_server_section.dart   /api/qr + modal toggle + snapshot slice
│   │   ├── settings/
│   │   │   └── settings_page.dart  fullscreen SettingsPage (display, clock, appearance,
│   │   │                           web remote, data & backups)
│   │   └── tasks/
│   │       ├── task_model.dart     TaskItem
│   │       ├── tasks_state.dart    Notifier<List<TaskItem>> + persistence
│   │       ├── tasks_card.dart     TasksCard
│   │       ├── tasks_server_section.dart  /api/tasks + WS commands + snapshot slice
│   │       └── task_form_content.dart     TaskFormContent + TaskPreviewCard
│   ├── server/                  feature-agnostic transport + seam
│   │   ├── web_server.dart      ShelfWebServer — lifecycle, assets, /ws, snapshot, backups
│   │   ├── server_section.dart  ServerSection/ServerRuntime interfaces (the seam)
│   │   ├── server_responses.dart  shared JSON body helpers
│   │   └── server_provider.dart  webServerProvider — wires sections ⇄ providers, auto-start
│   ├── theme/
│   │   └── theme.dart           AppColors, DuskTone presets, AppTheme
│   └── widgets/                 pure design system; imports nothing feature-specific
│       ├── bento_box.dart       rounded card container
│       ├── card_edit_button.dart  generic in-place popup menu (CardEditButton<T>)
│       ├── dusk_card_header.dart  uniform card title row (editButton widget slot)
│       ├── dusk_glass_button.dart
│       ├── dusk_glass_panel.dart
│       ├── dusk_glass_pill.dart
│       └── dusk_glass_segmented_control.dart
└── test/                        mirrors lib/ 1:1; see §14
```

**Import convention:** there are **no barrel files**. Imports name real files
(`package:wyrm_desk/features/habits/habits_card.dart`). Dependency rules:

- `features/` never imports other `features/` (home is the shell exception).
- `widgets/` is a design system — it must not import `config/` or `features/`;
  app-specific option lists are supplied by callers via generics
  (`CardEditButton<CardSize>` + `cardSizeMenuOptions()` from `config/`).
- `data/` and `server/` are feature-agnostic; features plug in via
  `ServerSection` (server) and section keys (persistence).
- Tests mirror `lib/` 1:1 (`test/features/<feature>/...`).

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
6. The server auto-starts on **port 8080 in release / 8081 in debug** (`kDebugMode`
   selects `ShelfWebServer.debugPort`), binding `InternetAddress.anyIPv4`.
7. `localIpProvider` (a `FutureProvider`) resolves the LAN IPv4 for display in the top bar
   and settings page.

---

## 6. Persistence layer — `lib/data/app_database.dart`

**Storage:** a single JSON file, `wyrm_database.json`, in
`getApplicationDocumentsDirectory()`. Written pretty-printed (2-space indent) behind a
serialized write queue (concurrent saves never interleave partial documents), with the
last-read document cached in memory. All errors are swallowed (test/sandbox friendliness),
so writes can silently no-op.

The database is **feature-agnostic**: it stores named JSON sections and owns only the
transport (disk IO, cache, write queue) and the whole-document backup engine. Every
feature owns its section key and the codec between its models and JSON — see the
`*_state.dart` files under `lib/features/` and `lib/config/`.

**Top-level document shape** (section keys on disk are snake_case-safe identifiers):

```jsonc
{
  "version": 1,
  "layout":   { "clock": "small", "habits": "small", "calendar": "small", "tasks": "small" },
  "settings": { "is_24_hour_format": false, "card_font_size": 14.0,
                "start_week_on_monday": false },
  "tasks":    [ /* TaskItem[]   */ ],
  "habits":   [ /* HabitItem[]  */ ],
  "calendar": [ /* CalendarMilestone[] */ ],
  "display":  { /* brightness */ }
}
```

**API (all `static`):**

| Member | Effect |
|---|---|
| `readDatabase()` | Reads the whole document; if missing/corrupt, runs `_initializeAndMigrateDatabase()`. |
| `writeDatabase(map)` | Queues an overwrite behind the write chain. |
| `readSection(key)` | Raw JSON value under a feature's key, or null when absent. |
| `writeSection(key, value)` | Replaces one section and persists the document. |
| `exportDatabaseJson()` | Whole document as a formatted JSON string. |
| `importDatabaseJson(raw)` | Validates (≥1 `knownSectionKeys` key required) and replaces the DB. |
| `exportToDownloads()` / `importFromDownloads()` | Device Downloads-folder backup round-trip (`wyrm_backup.json`). |
| `getDownloadsBackupModified()` | Last-modified timestamp of the Downloads backup, if present. |

**Legacy migration** (`_initializeAndMigrateDatabase`): if the unified file is absent, it
looks for older `card_layout.json` and `app_settings.json` files in the documents 
directory, imports them if present, and seeds a document with empty sections otherwise.

**Notifier persistence pattern:** each feature's notifier updates `state` synchronously
(optimistic), then writes its own section via `AppDatabase.writeSection` (fire-and-forget
for tasks/layout/settings; calendar, habits, and display await). `databaseServiceProvider`
(`lib/data/database_service.dart`) wraps import-and-reload: a restore re-seeds every
provider from the new document.

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
| `displayProvider` | `NotifierProvider<DisplayNotifier, DisplayState>` | screen brightness | see `lib/features/display/` |
| `networkModalOpenProvider` | `NotifierProvider<NetworkModalNotifier, bool>` | modal visibility | homepage `ref.listen`s it to show/hide the QR modal |
| `webServerProvider` | `Provider<ShelfWebServer>` | the server | side effects on creation; see §10 |
| `databaseServiceProvider` | `Provider<DatabaseService>` | persistence orchestration | import-and-reload used by restore |
| `localIpProvider` | `FutureProvider<String>` | LAN IPv4 string | used by top bar + settings |
| clock digit providers | `Provider.autoDispose<...>` | formatted strings/angles | in `lib/features/clock/clock_provider.dart` |

**Clock provider granularity** (`lib/features/clock/clock_provider.dart`): `clockTimeProvider` is a
1-second `StreamProvider`; `clockHoursProvider`, `clockMinutesProvider`,
`clockSecondsProvider`, `clockPeriodProvider`, `clockDateProvider`,
`timeLeftTodayPartsProvider`, `clockHandAnglesProvider`, and `clockBackgroundAssetProvider`
derive from it so only the parts that changed rebuild.

---

## 8. Domain models

### 8.1 `TaskItem` — `lib/features/tasks/task_model.dart`

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

### 8.2 `HabitItem` + `HabitType` — `lib/features/habits/habit_model.dart`

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

### 8.3 `CalendarMilestone` — `lib/features/calendar/calendar_model.dart`

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

`CalendarState` (`lib/features/calendar/calendar_state.dart`) holds `selectedDate`, `viewMonth`,
`milestones`, and computes `dayOfYear`, `daysInYear`, `yearProgress`, `currentQuarter`,
`quarterProgress`, `heroMilestone` (pinned first, else nearest upcoming), `relativeDistanceText`.

### 8.4 `CardSize` + `DashboardCardType` + `CardLayoutConfig` — `lib/config/card_layout_state.dart`

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

### 8.5 `AppSettingsConfig` — `lib/config/app_settings_state.dart`

```dart
class AppSettingsConfig {
  final bool is24HourFormat;          // JSON: "is_24_hour_format"
  final double cardFontSize;          // JSON: "card_font_size"  (default 14.0, clamped 11–22)
  final bool startWeekOnMonday;       // JSON: "start_week_on_monday"
}
```

> ⚠️ **Key-name mismatch to be aware of:** on-disk settings use snake_case, but the
> **server payload uses camelCase** (`is24HourFormat`, `cardFontSize`, `startWeekOnMonday`).
> The web client and server both speak camelCase. Only the DB file uses snake_case.

---

## 9. Dashboard layout engine — `lib/features/home/homepage.dart`

`HomePage` is a horizontal, single-axis scroll deck. Card widths are computed from the
`CardLayoutConfig` and the viewport width, then animated (380 ms, `easeInOutCubic`).

- **Deck widgets:** `_ScrollableDeck` wraps a `LayoutBuilder` and feeds the constraints
  into `_DeckRow`, which computes the column widths and builds the animated
  `SingleChildScrollView` row. The `GlobalKey`s for scroll-into-view live on `HomePage`.
- **Top bar** (`TopPillBar`, height 54) collapses to height 0 in Nightstand mode.
- **Padding** collapses to `EdgeInsets.zero` in Nightstand mode.
- **Scroll request** from the remote is handled via `ref.listen(cardScrollRequestProvider)`
  → `Scrollable.ensureVisible` on the card's `GlobalKey` (with a 400 ms re-align pass).
- **Network modal request** is handled via `ref.listen(networkModalOpenProvider)` →
  `NetworkConnectionModal.show/hide`.

**Width rules** (`_DeckRow.build`):

| Card | small | medium | fullscreen | nightstand |
|---|---|---|---|---|
| clock | 300 (or `(w-2*spacing)*3.1/14` when all-small & `w>1100`) | `clamp(w*0.55, 380, 900)` | `w` | `w` |
| habits | 360 | `clamp(w*0.55, 380, 900)` | `w` | n/a |
| calendar | 440 | `clamp(w*0.55, 380, 900)` | `w` | n/a |
| tasks | 340 (or `(w-2*spacing)*4.0/14` when all-small & `w>1100`) | `clamp(w*0.55, 380, 900)` | `w` | n/a |

**Center stacking:** when **both** `habits` and `calendar` are `small`, they stack vertically
in one column (width 540, or `(w-2*spacing)*6.9/14` when all-small & `w>1100`); otherwise each
becomes its own independent column.

`CardSize.nightstand` is only meaningful for the clock; it forces a pitch-black canvas with
glowing amber analogue + digital clock (`_ClockFullscreenView(isNightstand: true)`).

---

## 10. Embedded server — `lib/server/` + per-feature `ServerSection`s

### 10.1 The seam — `ServerSection` (`lib/server/server_section.dart`)

The transport is **feature-agnostic**. Every feature colocates its REST routes, WebSocket
commands, and snapshot slice in a `ServerSection` implementation (see the
`*_server_section.dart` files under `lib/features/` and `lib/config/`):

```dart
abstract interface class ServerSection {
  void registerRoutes(Router router, ServerRuntime runtime);
  bool handleMessage(Map<String, dynamic> message, ServerRuntime runtime);
  Map<String, dynamic>? snapshot();
}
```

`ServerRuntime` exposes `port` and `ipAddress` so sections never need the full server.
The first section whose `handleMessage` returns true consumes a WS message.

### 10.2 `ShelfWebServer` (`web_server.dart`)

Owns only: lifecycle (`start({port})` binds `InternetAddress.anyIPv4`, `stop()`), static
asset serving (with `htmlOverride/cssOverride/jsOverride/faviconOverride` strings/bytes for
headless tests), the `/ws` channel, the shared snapshot envelope, `/api/status`, and the
whole-database backup endpoints (`GET /api/backup/export`, `POST /api/backup/import`).

The snapshot envelope is the merge of the transport keys and every section's slice:

```jsonc
{ "type": "..." , "status": "online", "serverUrl": "http://<ip>:<port>", "ipAddress": "<ip>",
  ...<one slice per section, keyed layout/settings/tasks/habits/calendar/display/networkModalOpen> }
```

This single `_buildStateSnapshot()` serves the initial WS snapshot, every
`state_update` broadcast, and `GET /api/status`.

### 10.3 `webServerProvider` (`server_provider.dart`)

One `Provider<ShelfWebServer>` that:
1. Builds the server with all 7 sections, each wired to its Riverpod providers via getter
   and mutation callbacks (e.g. `TasksServerSection(getTasks:, onAddTask:, ...)`,
   `HabitsServerSection`, `CalendarServerSection`, `LayoutServerSection`,
   `SettingsServerSection`, `DisplayServerSection`, `NetworkServerSection`).
   Habit ids are `DateTime.now().millisecondsSinceEpoch.toString()`.
   Backup import goes through `databaseServiceProvider.importAndReloadJson` so every
   provider re-seeds after a restore.
   > `LayoutServerSection._executeSetLayout` resolves names case-insensitively and,
   > **after resizing, also triggers `onScrollToCard`** so the tablet scrolls the resized
   > card into view. Don't double-scroll in callers.
2. **Auto-starts** it (`server.start()`).
3. Registers `ref.listen` on **all seven** state providers (`cardLayoutProvider`,
   `appSettingsProvider`, `tasksProvider`, `calendarProvider`, `habitsProvider`,
   `displayProvider`, `networkModalOpenProvider`) → each change calls
   `server.broadcastState()`. **This is how tablet-originated changes reach the web remote.**
4. `ref.onDispose` stops the server.

### 10.4 Network discovery (`lib/features/network/network_info.dart`)

`NetworkInfo.getLocalIpAddress()` lists IPv4 interfaces, prefers wifi/eth-like names,
falls back to any non-loopback, and finally `127.0.0.1`. Exposed via `localIpProvider`.
The top bar and settings page render `http://<ip>:<port>`.

---

## 11. Server API — routes, REST, and WebSocket protocol

### 11.1 Static asset routes (served from `assets/web/` / `assets/icons/`)

| Route | Content-Type | Serves |
|---|---|---|
| `GET /` and `GET /index.html` | `text/html; charset=utf-8` | `assets/web/index.html` |
| `GET /style.css` | `text/css; charset=utf-8` | `assets/web/style.css` |
| `GET /app.js` | `application/javascript; charset=utf-8` | `assets/web/app.js` |
| `GET /favicon.ico`, `/icon_flat.png`, `/assets/icons/icon_flat.png` | `image/png` | `assets/icons/icon_flat.png` (falls back to `assets/web/icon_flat.png`) |
| `GET /assets/web/*` | Content-type inferred dynamically | Any file placed in `assets/web/` |
| `GET /<file.js|css|png|svg|json|webmanifest|ico|woff2?>` | Content-type inferred dynamically | Top-level asset files: `components.js`, `vue.global.prod.js`, `manifest.webmanifest`, … |

Assets are loaded **from disk first** (live updates during development), falling back to
Flutter's compiled `rootBundle` in release builds. JS/CSS/HTML/webmanifest are served with
`Cache-Control: no-cache, no-store, must-revalidate`; other binaries get a 1-day cache.

### 11.2 REST endpoints (all under `http://<ip>:<port>/api`)

`/api/status` returns the full snapshot envelope (see §10.2): `status`, `serverUrl`,
`ipAddress`, plus every section's slice — `layout`, `settings`, `tasks`, `calendar`,
`habits`, `display`, and `networkModalOpen`.

| Method | Endpoint | Body (JSON) | Effect |
|---|---|---|---|
| `GET` | `/api/status` | — | Full snapshot envelope (all sections). |
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
| `GET` | `/api/display` | — | `{brightness}` |
| `POST` | `/api/display` | `{brightness}` | set screen brightness |
| `POST` | `/api/modal/network` | `{open}` | show/hide the network connection modal on the tablet |
| `GET` | `/api/qr`, `/api/qr.svg` | — | SVG QR code encoding `http://<ip>:<port>` |
| `GET` | `/api/backup/export`, `/api/backup` | — | whole database as a JSON download |
| `POST` | `/api/backup/import` | full database JSON | validate + replace DB, then broadcast |

**Date parsing:** milestone dates accept ISO (`yyyy-mm-dd`, parsed by `DateTime.tryParse`)
or `dd/mm/yyyy` (see the calendar section's `_parseMilestoneDate`). Empty/invalid →
`DateTime.now()`. Habit completion dates accept ISO via `DateTime.tryParse`.

**Error convention:** invalid/empty payloads → `400` with `{"error": "..."}`. Success →
`{"success": true}` (scroll also returns `{"card": <name>}`; backup import returns
`{"status": "ok"}`).

### 11.3 WebSocket — `GET /ws`

On connect the server sends a **`snapshot`** message. Every state change on the tablet is
broadcast as a **`state_update`** to all connected clients (both have the same envelope
shape as `/api/status`; see §10.2):

```jsonc
{
  "type": "snapshot" | "state_update",
  "status": "online",
  "serverUrl": "http://<ip>:<port>",
  "ipAddress": "<ip>",
  "layout":   { "clock": "small", "habits": "medium", "calendar": "small", "tasks": "fullscreen" },
  "settings": { "is24HourFormat": false, "cardFontSize": 14.0, "startWeekOnMonday": false },
  "tasks":    [ { "id","title","is_completed","priority","created_at" } ],
  "calendar": {
      "today","selectedDate","viewMonth",
      "yearProgress","quarterProgress","dayOfYear","daysInYear","currentQuarter",
      "startWeekOnMonday","milestones":[ { "id","title","target_date","is_pinned","created_at" } ]
  },
  "habits":   [ { "id","title","type","target_value","unit","icon_name","color_hex","completions","created_at" } ],
  "display":  { "brightness": 0.8 },
  "networkModalOpen": false
}
```

**Client → server message types** (JSON, first field `type`):

| `type` | Additional fields | Maps to |
|---|---|---|
| `set_layout` | `card`, `size` | `onSetCardSize` (resize + scroll) |
| `set_settings` | any of `is24HourFormat`, `cardFontSize`, `startWeekOnMonday` | settings notifier |
| `set_display` | `brightness` | display notifier |
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
| `toggle_network_modal` | `open` | `onToggleNetworkModal` |
| `ping` | `timestamp` | server replies `{"type":"pong","timestamp":...}` |

Unknown types and malformed JSON are ignored (the listener wraps everything in try/catch).
The server never sends acknowledgements (except `pong`); clients learn the result from the
next broadcast.

---

## 12. Web remote client — `assets/web/`

Offline-bundled **Zero-Build Vue 3** application styled as a **Teenage Engineering / Dieter Rams** physical hardware remote control pad. Served verbatim by the tablet's Shelf server with zero external build step and zero cloud dependencies.

### 12.1 `index.html` — structure

- **Offline Vendor Runtime:** `<script src="/vue.global.prod.js"></script>` loads the bundled Vue 3 production runtime locally without CDN or internet connection.
- **Top Hardware Header (`header-brand`)**: Industrial wordmark (`WYRM REMOTE // V3`), live network telemetry capsule (`networkBadge` with `pulse-dot` and `networkLabel` showing `LIVE • XXms` or `CONNECTING...`), and Master Nightstand tactile rocker switch (`master-nightstand-btn`).
- **Physical Channel Bank Selector (`.channel-bank`)**: Hardware selector buttons with illuminated status LEDs:
  - `[1: DECK]` — Master card sizes (Clock, Habits, Calendar, Tasks) and global batch actions.
  - `[2: TASKS]` — Tasks matrix, checklist, priority toggles, and card font-size stepper.
  - `[3: HABITS]` — Habit tracker with 7-day dot-matrix history, binary toggles, numeric steppers, and glyph picker.
  - `[4: CAL]` — Temporal inspector, progress bars (year/quarter), month grid, and milestones manager.
  - `[5: SYS]` — System hardware controls, display brightness fader, 24-hour clock toggle, and backup import/export.
- **Declarative Vue Reactivity:** Uses standard Vue directives (`v-if`, `v-for`, `@click`, `v-model`, `:class`).

### 12.2 `style.css` — design system

Teenage Engineering / Braun retro-minimalist hardware design tokens:

```css
--bg-canvas:#0c0d10  --bg-chassis:#14161c  --bg-surface:#1b1e27  --bg-recessed:#08090b
--keycap-bg:#222632  --keycap-border:#32384a  --keycap-hover:#292e3c  --keycap-active:#171922
--border-subtle:#242936  --border-highlight:#384054
--accent-orange:#ff5500  --accent-amber:#ff9500  --accent-emerald:#00d084  --accent-cyan:#00b4d8
--text-primary:#f5f3e9  --text-secondary:#8d93a0  --text-muted:#525766
--font-mono:'JetBrains Mono','SF Mono',monospace  --font-sans:'Inter',sans-serif
```

- **Tactile Keycaps:** Physical button press depth (`transform: translateY(2px)` with mechanical shadow depression).
- **Recessed LCD Displays:** Inner shadow wells (`box-shadow: inset 0 2px 4px rgba(0,0,0,0.6)`) for status and telemetry.
- **Zero Heavy Shaders:** No expensive Gaussian blurs or heavy GPU filters, ensuring buttery 60 FPS performance on low-end client phones.

### 12.3 `app.js` — Vue 3 reactive engine

Built around Vue 3 `createApp` (components live in `components.js`, the reactive state in
`app.js`):

1. **`WyrmStateStore`** — wraps central reactive `state`:
   ```js
   { currentChannel: 'deck', isConnected: false, latencyMs: null,
     layout: { clock, habits, calendar, tasks },
     settings: { is24HourFormat, cardFontSize, startWeekOnMonday },
     display: { brightness },
     tasks: [], habits: [], calendar: { selectedDate, viewMonth, milestones } }
   ```
2. **`WyrmWebSocketManager`** — auto-reconnecting socket to `${ws|wss}://location.host/ws`,
   heartbeat `ping`/`pong` measuring round-trip latency (`Xms`), and transparent REST
   fallback for mutations.
3. **Vue 3 View Model (`vm`)** — computed helpers (`calendarCells`, `habitWeekDays`,
   `calendarMetrics`, `isNightstandActive`) and declarative mutation actions.
4. **Compatibility Bridge (`window.wyrmRemote`)** — exposes public methods for testing and
   headless scripting: `setCardSize`, `setAllCardsSize`, `scrollToCard`,
   `toggleStartWeekOnMonday`, `toggleNetworkModal`, `createMilestone`, `deleteMilestone`,
   `togglePinMilestone`, `createHabit`, `selectHabitGlyph`, `toggleHabit`, `stepHabit`,
   `deleteHabit`, `setBrightness`, `exportBackup`, `importBackup` (plus `store`, `wsManager`,
   `vm`).

---

## 13. Features (deep dive)

### Clock (`lib/features/clock`)
- `ClockContainer` renders per size: `DigitalClockSmall` (vertical: stacked time),
  `DigitalClockMedium` (horizontal), `ClockFullscreenView` (digital beside the squircle
  analogue), and nightstand (same fullscreen view, black + amber). Header is hidden in
  nightstand. Around whichever face is active the card lays its left rail: `ClockDateLine` on
  top, `ClockSunCountdown` pinned to the bottom-left.
- `ClockBackdrop` scales each time-of-day photograph to the card height and steps it across
  the spare width and back, so the whole panorama is seen over one cycle. The motion is a
  fixed **2 px jump every 50 ms** (40 px/s, no easing, no pause at the edges) set in
  `clock_backdrop_motion.dart` (`clockBackdropMotion`); the 1 s cross-fade there is used when
  the time-of-day photo changes. Deliberately stepped rather than tweened: the photograph is
  only resampled when it moves a whole pixel, and a frame lost to the 1 s clock tick delays one
  step instead of jumping the image. It is one `Transform` on a `RepaintBoundary` layer, driven
  by a `Timer` (not a ticker), so it stops when the card is scrolled out of the deck, when the
  app is backgrounded, or when `TickerMode` is off; `MediaQuery.disableAnimations` swaps it for
  a held centre crop.
- Each face sits in its own `RepaintBoundary` (`clock_card.dart`), so the per-second second-hand
  and seconds-digit repaint never re-rasterises the photograph and its scrim behind it.
- The date and the daylight countdown belong to the card, not the faces: `ClockContainer` stacks
  `ClockDateLine` above the face and `ClockSunCountdown` below it, so the left rail (date, time,
  countdown) lands on the same corner in all four tiers. A face that painted its own countdown
  would drift with its own `FittedBox`.
- The analogue face is a `CustomPainter` (`clock_face_analog.dart`) with discrete stepping
  hands; `clock_palette.dart` (`ClockTone`) holds every colour, `clock_numeral.dart` every
  numeral style.
- The dial is a **glass pane** in the standard tiers: `ClipRRect` + `BackdropFilter`
  (`ImageFilter.blur`, sigma in `ClockTone.glassBlur`) over the drifting photograph, a smoked
  wash (`ClockTone.glass`), a top sheen (`clockGlassSheen`), a hairline rim and a cast shadow
  (`clockGlassShadow`). Hands paint above the blur. `ClockTone.glassBlur == 0` selects the
  sealed branch instead — the nightstand tier, which stays an opaque black dial with an amber
  rim and no blur, because in a dark room the only light should be the amber.

### Habits (`lib/features/habits`)
- **Small:** one-habit carousel (`cycleCarousel`), numeric stepper or binary
  toggle, and a tappable 7-day week strip.
- **Medium/Fullscreen:** grid of habit tiles (1 col medium, 2 col fullscreen), each with
  edit/delete, today action, week strip, and a GitHub/calendar-style monthly heatmap.
- **Creation/edit:** `TwoPaneKeyboardScaffold` (default) or classic bottom sheet (setting),
  using `HabitFormContent` + `HabitPreviewTile`; icon picker, binary/numeric type, target, unit.

### Calendar (`lib/features/calendar`)
- **Small:** date banner (selected-date telemetry + Today/Travel/prev/next), month title,
  and a 7-column grid with milestone dots.
- **Medium/Fullscreen:** dual-pane — left month grid, right "Milestones & Countdowns"
  inspector with the milestone list (add/delete).
- `heroMilestone` logic and `relativeDistanceText` live in `CalendarState`.

### Tasks (`lib/features/tasks`)
- **Small:** checklist or screenshot-matching empty state ("All caught up"); count badge.
- **Medium/Fullscreen:** dual-pane Active Priorities / Completed columns.
- **Creation:** `TwoPaneKeyboardScaffold` with `TaskFormContent` + `TaskPreviewCard`.
- Font size for task/habit text comes from `AppSettingsConfig.cardFontSize` (11–22 pt).

### In-app keyboard (`lib/features/keyboard`)
Non-OS on-screen keyboard for a device that shouldn't summon the system IME.
- `InAppKeyboardController` (a `ChangeNotifier`) tracks the active `TextEditingController`,
  mode (`letters`/`symbols`/`numpad`), shift/caps, and implements insert/backspace/clear/
  cursor-move/submit.
- `InAppKeyboardScope` is an `InheritedNotifier` distributing the controller.
- `InAppKeyboardTextField` becomes `readOnly` when a scope is present (so it binds to the
  in-app keyboard) and normal otherwise.
- `TwoPaneKeyboardScaffold` lays out form (40% / flex 4) on the left and live preview +
  keyboard (60% / flex 6) on the right; narrow screens (< 720 px) stack vertically.

### Settings (`lib/features/settings/settings_page.dart`)
Opened from the top bar gear. Exposes: Display & Brightness slider, Nightstand mode toggle,
24-hour time, week start, card text size slider (11–22 pt) with live preview, a
**Web Remote Companion** card (status + `Show QR` → `NetworkConnectionModal`), and a
**Data & Backups** card (export/import `wyrm_backup.json` via Downloads).

---

## 14. Testing

`test/` mirrors `lib/` 1:1 (widget + unit + integration, `flutter_test`). Run with
`flutter test` (all) or `flutter test test/<path>`.

| File | Focus |
|---|---|
| `test/server/server_test.dart` | Starts a real `ShelfWebServer` on an ephemeral port with asset overrides; covers every static route, REST endpoint, the WS snapshot + command protocol, `NetworkInfo`, and asserts the `assets/web/*` files contain required tokens. **Update this when you change routes/messages or DOM ids/classes.** |
| `test/config/card_layout_state_test.dart` | `CardLayoutConfig` (de)serialization incl. nightstand. |
| `test/data/database_backup_test.dart` | `AppDatabase` backup/restore round-trips. |
| `test/features/home/home_page_test.dart` | Dashboard deck layout / sizing. |
| `test/features/home/homepage_deck_test.dart` | Deck shell: card rendering, in-place size popup menus, scroll/stack behaviour. |
| `test/features/clock/clock_card_test.dart` | Clock sizes + nightstand + providers/angles. |
| `test/features/habits/habits_test.dart` | Habit model math (streaks, heatmaps, weeks) + card layouts + glyph rendering. |
| `test/features/calendar/calendar_test.dart` | Milestone (de)serialization, progress metrics, Small/Medium layouts, travel picker. |
| `test/features/tasks/tasks_test.dart` | Task model tolerance + card rendering. |
| `test/features/settings/settings_page_test.dart` | Settings page rendering, narrow viewports, DuskTone theme. |
| `test/features/keyboard/two_pane_editor_test.dart` | Settings toggle, 40/60 split, form+preview widgets, cards opening the editor. |
| `test/features/keyboard/in_app_keyboard_test.dart` | Keyboard controller logic + scoped text field readOnly behavior. |

**Conventions used in tests:** `ProviderScope` with overridden providers; a `TestWidgetsFlutterBinding`;
`htmlOverride/cssOverride/jsOverride/faviconOverride` to avoid asset-bundle dependence;
`IOWebSocketChannel.connect` for live WS tests.

---

## 15. Design system

### Flutter palette (`lib/theme/theme.dart`)

```
background #020305   canvasAlt #0A0E11   surface #0E1418   surfaceElevated #141B20
well 30% black       line 10% white      lineStrong 16% white   glass 6% white
accentOrange #F2A768   accentRed #FF6B55   brandDot #EE7A45
priorityHigh #FF8F70   priorityMedium #F3C45E   priorityLow #8ED5B7
textPrimary #EEF2F1   textSecondary 68% white   textMuted 46% white   textOnLight #111111
```

`DuskTone` is a value type with static presets — `slate`, `teal`, `gold`, `rust`, `glacier` —
each carrying `top`/`bottom` gradient stops, `accent`, `fill`, `ink`, and `glow`. Card tone
mapping: Clock = slate, Habits = teal, Calendar = gold, Tasks = rust, Settings = glacier.
Nightstand accent = `#FF9500` amber (`_amber` in `clock_palette.dart`, the only place it exists).

### Web palette (`assets/web/style.css`)

Obsidian + amber "Liquid Glass" (see §12.2). Amber `#ff9500` is the signature brand signal.
The web palette and Flutter palette are intentionally *different* systems — do not try to
unify them blindly.

### Typography
- Flutter UI: default Material text; clock digits use **Barlow Condensed** (google_fonts).
- Web: `--font-sans` (SF Pro/Inter stack) and `--font-mono` for diagnostics.

---

## 16. Commands

```powershell
# Run on a device/emulator (server auto-starts on :8080 release / :8081 debug)
flutter run

# Analyze / lint (analyzer excludes platform dirs + build)
flutter analyze

# All tests / a single file
flutter test
flutter test test/server/server_test.dart

# Regenerate app icons (uses flutter_launcher_icons.yaml)
dart run flutter_launcher_icons

# Apply release naming across platforms (uses package_rename_release.yaml)
dart run package_rename
```

**Asset registration:** new assets must be added under `flutter: assets:` in `pubspec.yaml`.
Currently registered: `assets/icons/` and `assets/web/`.

**Web remote edits require no build step** — `assets/web/*` is served directly (from disk
first in debug). Bump the `?v=` query in `index.html` (for `style.css`/`app.js`) to defeat
client caching, and update the asset-token assertions in `test/server/server_test.dart` if
you rename ids/classes.

---

## 17. Known discrepancies & stale docs

| Artifact | Problem |
|---|---|
| `REFERENCE_STATE.md` | Describes SQLite schema, LWW sync, PIN `/api/auth/login`, `/api/sync`, `retro_colors.dart` — **none of which exist**. Current storage is a single JSON file; there is no auth. Kept only as a historical archive. |
| `docs/web_remote_architecture.md` | Describes a Flutter-Web admin, a latency heartbeat, `fetch('/api/status')` ping, and different endpoints/ids. The current client is a hand-written Vue 3 app (see §12). Kept only as a historical archive. |
| `wakelock_plus` in `pubspec.yaml` | Declared but unused in `lib/`. |
| Habit "today" | Web client computes today via UTC `toISOString()`; tablet uses local `dateKey()`. Divergence near midnight / non-UTC. |
| Dart ↔ web habit glyph maps | The emoji/icon token map is defined twice: `resolveHabitIcon`/`buildHabitGlyph` in `lib/features/habits/habit_form_content.dart` and the equivalent map in `assets/web/components.js`. They must be kept in sync by hand (web is frozen — no structural changes). |
| `README.md` | Untouched Flutter boilerplate. |

---

## 18. Conventions & how to work here

### Code style
- Dart: `flutter_lints`; use `const` where possible, doc-comment (`///`) public members,
  private helpers prefixed `_`, and match the existing "explain each public field" style.
- **No `_buildX()` helper methods** — every widget-building helper is a named (private)
  widget class instead, so widget identity is stable and `const` constructors are possible.
- Keep card widgets as `ConsumerWidget`/`ConsumerStatefulWidget`; read state with
  `ref.watch`, mutate with `ref.read(provider.notifier)`.
- Persist via `AppDatabase.writeSection('<feature-key>', ...)` right after state mutation,
  mirroring the existing per-feature notifier patterns.
- Web: vanilla Vue 3 + ES6, no bundler. The web remote is **structurally frozen** — make
  data/behaviour changes on the Dart side; only cosmetic web edits are acceptable.

### Adding a new card size option
1. Extend the `CardSize` enum in `lib/config/card_layout_state.dart` (and its
   `label`/`menuIcon`, plus `cardSizeMenuOptions`).
2. Handle it in the `_DeckRow` width logic in `lib/features/home/homepage.dart`.
3. Add the segmented button + `data-card` handling in `assets/web/index.html`/`app.js`.
4. Update `test/server/server_test.dart` asset assertions if ids change.

### Adding a new remote-controlled feature (end-to-end)
1. Add the model/state in its feature folder under `lib/features/`, persisting through a
   `AppDatabase.writeSection` key.
2. Create a `<feature>_server_section.dart` implementing `ServerSection` (routes + WS
   commands + snapshot slice) in the same folder.
3. Register the section in `lib/server/server_provider.dart`, wire its callbacks, and add a
   `ref.listen` broadcast for the feature's state provider.
4. The section's `snapshot()` slice automatically appears in `/api/status` and the WS
   snapshot/state_update payload.
5. Add the UI + `window.wyrmRemote` command in `assets/web/*` (cosmetic only — web frozen).
6. Extend `test/server/server_test.dart` (REST + WS) and add `test/features/<feature>/`.

### Things to be careful about
- **Never break the snapshot/broadcast envelope shape** without updating `app.js`
  (`_handleIncomingMessage` and the renderers) and `test/server/server_test.dart`.
- The snapshot is merged from each section's `snapshot()` slice, so new state must be
  exposed through its owning section.
- `_executeSetLayout` implicitly scrolls; don't double-scroll in callers.
- Settings have **camelCase on the wire, snake_case on disk**.

---

## 19. Quick reference

- **Default port:** `8080` release / `8081` debug (`ShelfWebServer.defaultPort`), bound to `anyIPv4`.
- **WebSocket path:** `/ws` (snapshot → state_update; `ping` → `pong`).
- **Persisted file:** `<appDocuments>/wyrm_database.json`; backup file `wyrm_backup.json`.
- **Disk section keys:** `layout`, `settings`, `tasks`, `habits`, `calendar`, `display`.
- **Asset roots:** `assets/icons/`, `assets/web/`, `assets/card_bg/clock/`, `assets/card_bg/task/`.
- **Remote URL format:** `http://<lan-ip>:<port>`.
- **Card sizes:** `small`, `medium`, `fullscreen`, `nightstand` (clock only).
- **Card ids / `data-card`:** `clock`, `habits`, `calendar`, `tasks` (+ `all` pseudo-card).
- **Settings keys (wire):** `is24HourFormat`, `cardFontSize`, `startWeekOnMonday`.
- **Settings keys (disk):** `is_24_hour_format`, `card_font_size`, `start_week_on_monday`.
- **Habit icon tokens:** `bolt`, `spa`, `water_drop`, `fitness_center`, `menu_book`,
  `directions_run`, `bedtime`, `wb_sunny`, `code`, `local_cafe`, `check_circle`, `favorite`.
