<div align="center">

<img src="assets/brand/assets/icon/dark/OpenProcess-dark-256.png" width="128" height="128" alt="OpenProcess icon">

# OpenProcess

**Everything your Mac is doing, in real time.**

A native, open-source Activity Monitor replacement for macOS.

[![License](https://img.shields.io/github/license/Im-Fran/openprocess)](LICENSE)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-268CFF)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)

**English** · [Español](README.es.md)

</div>

---

## 📖 Overview

OpenProcess shows everything happening on your Mac in real time: system and user processes, CPU usage **core by core**, the GPU, memory and memory pressure, power draw in watts, temperatures, disk, and network. It also lets you act on processes: quit them, force them to quit, send them signals, inspect them, and sample them.

It was born because Activity Monitor falls short for people who open it every day. It doesn't show each core's load grouped by cluster (performance / efficiency), per-process GPU usage, each process's actual power draw in watts, or temperatures. OpenProcess adds all of that while still looking and behaving like an Apple app: a full menu bar, keyboard shortcuts, an inspector, light and dark mode, and a confirmation before every destructive action.

It's written in **SwiftUI** with a native `NSOutlineView` for the process list. SwiftUI's table spent more than 10 % CPU re-sorting ~750 rows; the native table keeps the app's own usage around 6 % with the window open and ~2 % with only the menu bar icon, refreshing every 2 seconds. It ships **outside the App Store** as a DMG signed with Developer ID and notarized, because a sandboxed app can't see or manage other users' processes.

<p align="center">
  <img src="assets/brand/assets/screenshots/app-cpu-dark.png" width="820" alt="CPU section in dark mode: total usage and every core grouped by cluster">
</p>

---

## ✨ Features

- **Processes** — The full list (~750 on a typical Mac) as a flat list or a **hierarchical tree**. Search by name, PID, user, or path, and filter by all, mine, system, other users, and windowed apps. Columns can be shown, hidden, and sorted from the header or from the *View* menu:
  - CPU % and CPU time;
  - how much ran on Performance Cores;
  - threads, memory, and GPU %;
  - energy in watts and wakeups;
  - disk reads and writes;
  - network received and sent.
- **Inspector** (⌘I) — Process activity chart, path, arguments, parent process, open files and ports (`lsof`), and a 3 s sample with `sample`, with the option to save the report.
- **Process actions** — Quit (⌥⌘Q), force quit, and send any signal: `SIGINT`, `SIGHUP`, `SIGTERM`, `SIGQUIT`, `SIGSTOP`, `SIGCONT`, `SIGUSR1`, `SIGUSR2`, and `SIGKILL`. All of them ask for confirmation, like Activity Monitor.
- **CPU** — User and system usage, load average, and a grid with every core grouped by cluster (for example, on an M5: 4 Super Cores and 6 Efficiency Cores).
- **GPU** — Device, renderer, and tiler utilization, memory in use, and a per-process ranking.
- **Memory** — Pressure (Normal / Warning / Critical, with an icon and text, not just color) and a breakdown into apps, wired, compressed, cached, purgeable, free, and swap. A *Purge Memory* button.
- **Energy** — Total system power (SMC), GPU watts (IOReport), CPU estimated from each process, SoC temperature, every thermal sensor, and battery status (charge, cycles, maximum capacity).
- **Disk and network** — Live rates, totals since boot, and the processes that read, write, download, or upload the most.
- **Menu bar** — A 5-bar glyph that reflects live core load, next to the CPU %. Clicking it opens a compact panel with CPU, GPU, memory, pressure, network, energy, per-core bars, and the top processes. The app keeps measuring even after you close the window.
- **Languages** — English (default) and Latin American Spanish. It follows the system language; you can change it for the app alone in *System Settings ▸ General ▸ Language & Region*. Strings live in `OpenProcess/Resources/Localizable.xcstrings`, with English as the base language.
- **Privileged helper (optional)** — A system helper, installed with `SMAppService`, that lets you see metrics for root's and other users' processes, quit them, and purge memory. The app and the helper only talk to each other if both are signed by the same team.

<p align="center">
  <img src="assets/brand/assets/screenshots/app-resumen-light.png" width="820" alt="Overview section in light mode: CPU, memory, GPU, energy, disk, and network cards">
</p>

---

## 🛠 Tech stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, Swift Charts, and AppKit's `NSOutlineView` for the process table |
| Language | Swift 6 (strict concurrency) |
| Metrics | `libproc` / `proc_pid_rusage`, `sysctl`, Mach (`host_processor_info`, `host_statistics64`), IOKit, IOReport, SMC, `IOHIDEventSystemClient`, `nettop` |
| Helper | Launch daemon with `SMAppService` and XPC (`NSXPCConnection`) |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`); the `.xcodeproj` isn't versioned |
| Signing and distribution | [fastlane](https://fastlane.tools) + match, Developer ID, notarization, DMG with [dmgbuild](https://github.com/dmgbuild/dmgbuild) |
| CI | GitHub Actions (`.github/workflows/release.yml`) |

---

## 📥 Installation

1. Download the latest `OpenProcess-<version>.dmg` from [Releases](https://github.com/Im-Fran/openprocess/releases).
2. Open it and drag **OpenProcess** to the **Applications** folder.
3. *(Optional)* To see and manage other users' processes, open **OpenProcess ▸ Settings…**, click **Install Helper…**, and approve it in **System Settings ▸ General ▸ Login Items**.

> Without the helper, OpenProcess lists **every** process, but metrics for processes owned by root or other users show as "—".

**Privacy:** OpenProcess sends nothing to the internet. All information is read locally from the system.

---

## 📋 Build requirements

- **macOS 26** or later, on a Mac with Apple Silicon
- **Xcode 26** or later (the icon is an Icon Composer `.icon` file)
- **XcodeGen** — `brew install xcodegen`
- **Ruby 4** and **Bundler** for fastlane (`Gemfile.lock` uses the Bundler 4 format)
- **uv** to build the DMG — `brew install uv`
- To sign and notarize: a **Developer ID Application** certificate and an **App Store Connect API key**

---

## 🚀 Getting started

### 1. Clone the repository

```bash
git clone https://github.com/Im-Fran/openprocess.git
cd openprocess
```

### 2. Generate the Xcode project

```bash
xcodegen generate
open OpenProcess.xcodeproj
```

The project is generated from `project.yml`. If you add or remove files, run `xcodegen generate` again.

### 3. Build and run

From Xcode with the **OpenProcess** scheme, or from the terminal:

```bash
xcodebuild -project OpenProcess.xcodeproj -scheme OpenProcess -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/OpenProcess.app
```

The Debug configuration signs with **Apple Development** for team `PX7HA29NR3`. To build without a certificate, add `CODE_SIGNING_ALLOWED=NO`; the privileged helper won't work in that case.

### 4. Run the tests

```bash
bundle install
bundle exec fastlane test              # signed
bundle exec fastlane test signed:false # without a certificate (as in CI)
```

---

## 🏗 Building for distribution

Every lane regenerates the project before building.

| Command | What it does |
|---------|----------|
| `bundle exec fastlane certificates` | Installs the Developer ID certificate and the *Direct* profile from the match repository (read-only) |
| `bundle exec fastlane certificates readonly:false` | Creates or renews the *Direct* profile on the portal and uploads it to match |
| `bundle exec fastlane build` | Archives and exports `build/OpenProcess.app` signed with Developer ID, and checks the signing requirements of the app and the helper |
| `bundle exec fastlane dmg` | Packages the already-built app into `build/OpenProcess-<version>.dmg`, without notarizing |
| `bundle exec fastlane release` | Build, app notarization, DMG, and DMG notarization |
| `bundle exec fastlane release version:1.2.0 build_number:7` | The same, pinning the version and build number |

### fastlane environment variables

Copy the template and fill it in. `fastlane/.env` is in `.gitignore`.

```bash
cp fastlane/.env.example fastlane/.env
```

| Variable | Description |
|----------|-------------|
| `ASC_KEY_ID` | Key ID of the App Store Connect API key. The `.p8` goes in `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` |
| `ASC_ISSUER_ID` | The team's Issuer ID in App Store Connect |
| `MATCH_REPOSITORY_URL` | Private git repository where match stores the encrypted certificate and profile |
| `MATCH_PASSWORD` | Password that decrypts that repository |

---

## 🌐 Publishing a release

The [`release.yml`](.github/workflows/release.yml) workflow runs on every tag. It runs the tests, runs `fastlane release`, verifies signing and notarization with `spctl` and `stapler`, and publishes a GitHub Release with the DMG and its `checksums.txt`.

```bash
git tag v1.0.0      # version 1.0.0, build = workflow run number
git tag v1.0.0+7    # version 1.0.0, build 7
git push origin --tags
```

Required repository secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (the `.p8` in base64), `MATCH_REPOSITORY_URL`, `MATCH_PASSWORD`, and `MATCH_GIT_BASIC_AUTHORIZATION` (base64 of `user:token` with read access to the match repository).

---

## 🗂 Project structure

```
OpenProcess/
├─ App/          entry point, menus and shortcuts, Settings
├─ Model/        SystemMonitor (observable state), history, UI state
├─ Sampling/     readers for processes, CPU, memory, GPU, disk, network, and energy
├─ Helper/       privileged helper client (SMAppService + XPC)
├─ Shared/       XPC protocol and stats shared with the helper
├─ Views/        process table, inspector, sections, and menu bar
└─ Resources/    AppIcon.icon (Icon Composer), Assets.xcassets, Localizable.xcstrings, entitlements
OpenProcessHelper/  privileged launch daemon and its launchd plist
OpenProcessTests/   unit tests
assets/             branding (see assets/README.md)
fastlane/           build, signing, notarization, and DMG lanes
packaging/          DMG configuration
```

The branding (icon, menu bar glyph, palette, and DMG background) is documented in [`assets/README.md`](assets/README.md).

---

## 🕸 Knowledge graph (graphify)

[graphify](https://github.com/safishamsi/graphify) turns the repository into a knowledge graph: it extracts code symbols through the AST, concepts and design decisions from the documentation, and the content of images, and groups them into communities. We use it to find our way around the architecture and so AI assistants query the graph instead of reading the whole codebase for every question.

The graph is local: it isn't versioned, and everyone generates it in `graphify-out/` (ignored in `.gitignore`):

| File | Contents |
|---------|-----------|
| `GRAPH_REPORT.md` | Most connected nodes, communities, surprising connections, and ambiguous edges |
| `graph.html` | Interactive visualization; opens in the browser, no server needed |
| `graph.json` | The full graph, for queries |

It's used as a Claude Code skill (`pip install graphifyy`):

```bash
/graphify .                       # builds the full graph
/graphify . --update              # re-extracts only the files that changed
/graphify query "how does a CPU sample reach the process table?"
/graphify path "NetworkSampler" "ProcessTable"
/graphify explain "SystemMonitor"
```

Every relationship is tagged `EXTRACTED` (explicit in the code), `INFERRED` (deduced by the model), or `AMBIGUOUS` (needs review). After changing code or documentation, run `/graphify . --update` to keep your graph up to date.

---

## ⚠️ Known limitations

- GPU energy (IOReport), total system power (SMC), and temperatures (`IOHIDEventSystemClient`) use **private Apple APIs**. If they break in a future macOS version, that information is hidden and the rest of the app keeps working.
- On recent chips, macOS doesn't expose CPU energy without privileges. OpenProcess **estimates** it by adding up the power each readable process reports; with the helper installed, the sum includes system processes.
- Per-process network usage comes from running `nettop` once per cycle (~30 ms).

---

## 🤝 Contributing

Contributions are welcome:

1. Fork the repository.
2. Create a branch: `git checkout -b feat/your-change`.
3. Commit with [Conventional Commits](https://www.conventionalcommits.org/): `git commit -m "feat(ui): add ..."`.
4. Make sure `bundle exec fastlane test` passes.
5. Open a pull request against `dev`.

---

## 📄 License

OpenProcess is free software under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file.

---

<div align="center">
Made with ☕ by <a href="https://franciscosolis.cl">Fran</a>
</div>
