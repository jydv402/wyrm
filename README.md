<div align="center">

<img src="assets/icons/icon_flat.png" alt="Wyrm Desk Logo" width="96" height="96" />

# Wyrm Desk

**Turn any Android tablet into an ambient desk companion and smart dashboard.**

[![Latest Release](https://img.shields.io/github/v/release/jydv402/wyrm_app?color=8CC8DC&label=Latest%20Release&style=flat-square)](https://github.com/jydv402/wyrm_app/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android%20Tablet-F2A768?style=flat-square)](https://github.com/jydv402/wyrm_app)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)

<br/>

[**Download Latest APK**](https://github.com/jydv402/wyrm_app/releases/latest) • [**Screenshots**](#-interface-showcase) • [**Features**](#-features) • [**Quick Start**](#-quick-start) • [**Architecture**](#-under-the-hood)

<br/>

</div>

---

## ✦ What is Wyrm Desk?

Have an older Android tablet sitting in a drawer? **Wyrm Desk** breathes new life into it by turning it into a dedicated landscape desk companion. 

It serves as a live dashboard for your time, habits, calendar, and daily focus.

Best of all, **your tablet is also a local server**. Without installing any apps on your phone or laptop, you can wirelessly control and update your tablet dashboard from any web browser on your Wi-Fi network.

---

## ✦ Interface Showcase

### Tablet Ambient Dashboard
*A dedicated landscape display featuring a live dynamic clock, habit contribution heatmap, calendar countdown milestones, and priority checklist.*

<img src="public/wyrm_home.png" alt="Tablet Ambient Dashboard" width="100%" />
<br/>

### Demo video
*Contains resizable cards and auto-scroll to card. All of which can be controlled from the web remote.*
<video src="public/wyrm_demo.mp4" autoplay loop muted playsinline width="100%"></video>
<br/>

### Browser Web Remote Companion
*A zero-install companion interface hosted directly by the tablet for wireless management from any phone or laptop on your Wi-Fi network.*

<img src="public/wyrm_remote.png" alt="Browser Web Remote Companion" width="100%" />

---

## ✦ Features

### ⏱️ Dynamic Clock & Bedtime Nightstand
- **Multiple Clock Faces:** Clean digital clock with condensed typography, discrete analogue instrument dial, and dynamic photographic backdrops.
- **Daylight Photography Drift:** The clock backdrop subtly shifts throughout the day (morning fog, daytime warmth, golden hour, and midnight calm).
- **Nightstand Mode:** Switch to an ultra-low glare, pitch-black amber display with a single tap for bedside nightstand duty.
- **Day Countdown:** A live countdown pill tracks the hours and minutes remaining today.

### 🌿 Daily Habits with Heatmap Matrix
- **GitHub-Style Heatmap:** Visualize consistency across the entire month with a 7-row weekday contribution matrix.
- **Streak Counters:** Track active daily streaks and completion momentum at a glance.
- **One-Tap Stepping:** Check off habits or step multi-count goals directly from the tablet or remotely.

### 📅 Calendar & Countdown Milestones
- **Interactive Month View:** Fluid month browsing with configurable week start.
- **Countdown Milestones:** Pin high-priority deadlines, trips, and milestones with live days-remaining badges.
- **Year & Quarter Progress:** Glanceable fraction indicators show current progress through the quarter and year.

### ⚡ Priority Task Checklist
- **Three-Tier Priority System:** Color-coded tasks with dedicated `HIGH`, `MED`, and `LOW` priority tags.
- **Tactile Checkbox Animations:** Satisfying tactile completion with instant visual feedback.

### 📡 Zero-Install Web Remote Companion
- **Control from Any Browser:** The tablet hosts an embedded HTTP + WebSocket server on your local Wi-Fi.
- **Instant QR Pairing:** Tap the Wi-Fi pill on your tablet, scan the QR code with your phone or access the port address on desktop browser, and start adding tasks or marking habits instantly.
- **Live Bidirectional Sync:** Mutations from the web remote reflect on the tablet in real time with sub-millisecond local latency.

### 🔒 100% Offline-First & Private
- **Zero Cloud, Zero Accounts:** All data remains strictly on your device inside an offline JSON document store.
- **Easy Backups:** One-tap export and import directly to your tablet's `Downloads` folder, or backup wirelessly from your computer via the Web Remote.

---

## ✦ Quick Start

Get your tablet running in two simple steps:

1. **Install Wyrm Desk on your tablet:**
   - Grab the appropriate APK from the [**Releases Page**](https://github.com/jydv402/wyrm/releases/latest):
     - `arm64-v8a`: Most modern tablets (64-bit ARM). Recommended for almost all devices from 2016 onward.
     - `armeabi-v7a`: Older budget or legacy tablets (32-bit ARM, including older Amazon Fire tablets).
     - `x86_64`: Intel or AMD-based devices, ChromeOS, and desktop Android emulators.
     - `universal`: Combined build that works on any device. Choose this if you are unsure about your tablet's processor.
   - Sideload and launch the app on your Android tablet (Android 7.0+ recommended).

2. **Connect your phone or laptop:**
   - Make sure your phone/laptop is on the same Wi-Fi network as the tablet.
   - Tap the **Wi-Fi status pill** on the top navigation bar of the tablet to open the Web Remote modal.
   - Scan the QR code with your phone camera or visit `http://<tablet-ip>:8080` in your browser.
   - You can now create tasks, track habits, and control your tablet dashboard remotely.

---

## ✦ Under the Hood

| Area | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.x, Material 3 Dark) |
| **State Management** | [Flutter Riverpod](https://riverpod.dev) v3 (`Notifier`, `ProviderScope`) |
| **Local Remote Server** | [Shelf](https://pub.dev/packages/shelf) HTTP + WebSockets on local port 8080 |
| **Web Remote UI** | Vue 3 |
| **Persistence** | Atomic local JSON store (`lib/data/app_database.dart`) with Downloads backup engine |

---

## ✦ Star History

<a href="https://www.star-history.com/?repos=jydv402%2Fwyrm_app&type=date&logscale=&releases=&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=jydv402/wyrm_app&type=date&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=jydv402/wyrm_app&type=date&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=jydv402/wyrm_app&type=date&legend=bottom-right" />
 </picture>
</a>

---

<div align="center">
  <sub>Crafted with passion for ambient desk setups. Star the repository if you find it helpful!</sub>
</div>
