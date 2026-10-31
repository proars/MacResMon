# MacResMon — macOS System Monitor for Apple Silicon

**Free, open-source Mac system monitor with live CPU and GPU usage, temperature monitoring, fan speed (RPM), and a menu bar readout.**

See memory usage, power consumption, battery status, disk activity, network speed, and top processes in one window. MacResMon pairs a native Swift shell with a bundled React interface in WKWebView. Sensor access needs no `sudo` or kernel extensions; the app runs without Electron or a Node.js runtime.

> **Apple Silicon only.** Intel Macs are not supported: the sensor source, [macmon](https://github.com/vladkens/macmon), reads Apple Silicon performance counters that Intel Macs do not have. On an Intel Mac the app will not give you CPU, GPU, power, temperature or fan data.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 13+ Apple Silicon](https://img.shields.io/badge/macOS-13%2B%20Apple%20Silicon-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshot-dark.png">
  <img src="docs/screenshot-light.png" alt="MacResMon window showing CPU, GPU and memory load, per-core usage, fan speed graph, power, battery, storage, network and top processes on an Apple Silicon Mac" width="900">
</picture>

*Current interface with demo readings, shown in light or dark mode according to your preferred color scheme. [Light screenshot](docs/screenshot-light.png) · [Dark screenshot](docs/screenshot-dark.png).*

[Features](#features) · [Build and run](#build-and-run) · [FAQ](#faq) · [Troubleshooting](#troubleshooting) · [Contributing](#contributing)

## Why MacResMon?

When your MacBook Pro gets hot or its fans spin up, check temperatures, fan RPM, CPU and GPU load, power draw, and the busiest processes together. Keep the live CPU and temperature readout in the macOS menu bar, then open the dashboard for a closer look.

MacResMon monitors your Mac; it does not change fan speeds, CPU settings, or thermal limits.

## Features

- **Cooling**: a spinning rotor per fan (speed follows RPM), one filled graph with a line per fan, and a live legend with RPM and % of maximum
- **CPU, GPU, memory**: load rings, thermometers in °C or °F, swap, 60-sample trends (one minute at the default interval), and a load column for every CPU core, grouped by Performance and Efficiency cluster
- **Power and battery**: whole-system watts, chip (CPU + GPU + ANE + RAM), CPU and GPU power, charge level, charging state, time left and power adapter wattage
- **Top processes**: top 5 by CPU and by memory, to answer "what is heating the Mac?"
- **Storage and network**: free space, disk read/write speed, download and upload in MB/s and Mbps
- **Menu bar**: a fan icon with a live readout (CPU % and temperature, `⚠︎` while an alert is active) and a menu with the details
- **Alerts and notifications**: alert chips in the window header (the two most severe, plus "+N") and a macOS notification when CPU or GPU reaches 90 °C, a fan reaches 95% of its maximum speed, memory is 90% full, the battery is at 10% or the disk is almost full; they also arrive while the window is closed
- **Settings** (⌘,): launch at login, show the menu-bar item, keep running when the window is closed, notifications (with a test button), temperature unit, update interval (0.5, 1, 2 or 5 seconds; 1 by default). All settings are remembered between launches
- Light and dark theme, and an app icon

## Requirements

An **Apple Silicon Mac running macOS Ventura 13 or later** is required. Intel Macs are unsupported. Available sensor readings depend on your Mac model and macmon; fanless Macs have no fan RPM to report. Testing so far has been on one Apple Silicon MacBook Pro, so reports from other models are welcome.

To build from source, install:

| Tool | Needed for | Install |
| --- | --- | --- |
| Mac with Apple Silicon, macOS 13+ | everything | |
| [macmon](https://github.com/vladkens/macmon) | sensor data (CPU, GPU, power, temperatures, fans); copied into the app when you build it | `brew install macmon` |
| Swift (Xcode Command Line Tools; full Xcode is not needed) | building the app | `xcode-select --install` |
| [Node.js](https://nodejs.org) 18+ | building the interface (the app itself does not use Node) | `brew install node` |

## Build and run

Clone this repository using GitHub’s **Code → HTTPS** URL, or choose **Download ZIP** and extract it. Open Terminal in the project folder, then run:

```bash
npm install                               # once
npm run native:build                      # builds "native/build/MacResMon.app"
open "native/build/MacResMon.app"
```

The build packs the interface, the Swift app and a copy of `macmon` into one app of about 3.5 MB. Copy it to `/Applications` if you like, and rebuild with the same command after changing any code.

The build signs the app ad hoc, without Developer ID signing or notarization. A downloaded or AirDropped copy may be blocked by Gatekeeper on another Mac. If you trust the source, try opening it, then use **System Settings → Privacy & Security → Open Anyway** if macOS offers that option. Developer ID signing and notarization are planned for distribution.

### What `build.sh` does

`npm run native:build` runs `native/build.sh`, which stops at the first error (`set -euo pipefail`) and works in these steps:

1. Finds `macmon`: `$MACMON_BIN` if set, otherwise the one on your `PATH`. Without it the script exits with a hint to run `brew install macmon`.
2. Builds the interface (`npm run build`, output in `dist/`).
3. Builds the Swift app in release mode (`swift build -c release`).
4. Assembles `native/build/MacResMon.app`. The old bundle is deleted first. It holds the executable, `dist/`, the icon (`Resources/AppIcon.icns`, drawn by `Tools/make-icon.sh` only if missing), `macmon` in `Contents/Resources/bin`, the license notices of macmon and of this project, and an `Info.plist` written by the script (bundle ID `com.macresmon.app`, minimum macOS 13, version taken from `package.json`).
5. Signs the bundle ad hoc (`codesign --sign -`).

Run it from anywhere; it changes into `native/` itself. To use a different macmon: `MACMON_BIN=/path/to/macmon npm run native:build`.

### Make a .dmg

After `npm run native:build`, pack the app into a disk image with `hdiutil` (part of macOS):

```bash
mkdir -p native/build/dmg
cp -R "native/build/MacResMon.app" native/build/dmg/
ln -s /Applications native/build/dmg/Applications     # drag-to-install shortcut
hdiutil create -volname "MacResMon" -srcfolder native/build/dmg \
  -ov -format UDZO native/build/MacResMon.dmg
rm -rf native/build/dmg
```

The result is `native/build/MacResMon.dmg`. It carries the same ad-hoc signature as the app, so the first-launch warning described above applies on other Macs.

## Using the app

- **Window**: ⌘R reloads the interface. Closing the window only hides it while "Keep running in the menu bar" is on (the default); click the Dock or menu-bar icon to bring it back. Quit with ⌘Q or from the menu-bar item.
- **Menu bar**: click the fan icon for CPU, GPU, memory, fans, power, battery and active alerts, or to open the window or Settings.
- **Notifications**: macOS asks for permission the first time one is needed (or when you press "Send test notification" in Settings).
- **Launch at login**: switch it on in Settings. macOS may ask you to approve it in System Settings › General › Login Items; Settings has a button that opens it.
- The temperature unit (°C, °F or follow the system region) is set in Settings only and applies to the window, the menu bar and notifications.

## How it works

```
macmon (child process)       ┐
ps · pmset · df              ├─> Swift Sampler/Monitor ──(1 s by default)──> window.__nativeHub ──> React UI in a WKWebView
getifaddrs · IOKit (counters)┘        │
                                      └─> menu-bar item, alert notifications
```

The Swift side reads [macmon](https://github.com/vladkens/macmon) (CPU, GPU, power, temperatures, fans, memory), a few macOS tools (processes, battery, disk space) and direct system counters (network, disk I/O). Once per update interval (1 second by default, set in Settings) it builds one snapshot, keeps the last 60 samples, feeds the menu bar and notifications, and pushes the snapshot into the page. The interface is a small React app drawn with plain SVG (no chart library), built with Vite and bundled into the app; the page is only fed while the window is visible.

```
native/   Swift package: MonitorCore (parsers, snapshot, alert rules) · MacResMon (window, menu bar,
          notifications, settings) · CoreChecks (unit checks) · build.sh · Tools/make-icon
src/      the React interface (cards, hooks, header alert chips)
docs/     README screenshots
```

## Development

| Command | What it does |
| --- | --- |
| `npm run native:build` | builds the interface and the app |
| `npm run build && npm run native:dev` | runs the app without packaging (uses `dist/` and the `macmon` in `/opt/homebrew/bin` or `/usr/local/bin`; notifications and launch at login need the real app) |
| `npm test` | interface logic: formatters and alert rules |
| `npm run native:check` | the Swift parsers, snapshot builder and alert rules (no Xcode needed) |
| `node rendercheck.mjs` | renders every component server-side as a smoke test |
| `npm run native:icon` | redraws the app icon |

Checks without looking at the screen: run the app binary with `--screenshot FILE` (PNG of the window), `--screenshot-settings FILE` or `--dump-status` (prints the menu-bar title and rows). Environment variables: `MACMON_BIN` (path to macmon) and `MONITOR_DIST` (path to a built interface).

Repository metadata and release notes are covered under [Publishing on GitHub](#publishing-on-github).

## FAQ

**How do I check fan speed and CPU temperature on an Apple Silicon Mac?**
The Cooling card shows each reported fan’s RPM and history graph; the CPU and GPU cards show temperatures. MacResMon uses macmon for Apple Silicon sensor data, including M-series Macs such as M1, M2, M3, M4, and M5. Readings depend on model and macmon support; this is not a claim that every model has been tested. A missing fan reading can mean a fanless Mac or unavailable sensor data.

**Can MacResMon control fan speed?**
No. It is a fan speed monitor, not a fan controller. macOS continues to manage cooling.

**Is this an Activity Monitor alternative?**
MacResMon is useful for a combined hardware dashboard with temperatures, fan RPM, power draw, and a menu bar readout. Activity Monitor provides more detailed process inspection and process management; MacResMon shows the top five CPU and memory consumers.

**Does it need `sudo`?**
No. Sensor data comes from [macmon](https://github.com/vladkens/macmon), which reads Apple's performance counters without root.

**Does it work on Intel Macs?**
No. macmon supports Apple Silicon only, and the app has no other sensor source, so it does not work on Intel Macs. Support would need a separate reader for Intel (temperatures and fans through the SMC); it is not planned yet.

**Is it on the Mac App Store?**
No. The current installation path is to build the app from source using the instructions above.

**Is my data sent anywhere?**
No. The app has no server and makes no network connections; everything stays on your Mac.

**Why is the interface built with web technology?**
It keeps the charts easy to change and to preview; the native Swift shell does everything that needs the system (sensors, menu bar, notifications, launch at login). Node is only used to build the interface.

**Which Macs has it been tested on?**
It was developed and tested on a single Apple Silicon MacBook Pro. Reports for other models are welcome as issues.

## Known limitations

- **Sensor coverage:** Apple Silicon only; readings vary by hardware and macmon support. There is no fan control.
- **Visible-window memory use:** the WKWebView WebContent process has shown memory growth while the dashboard stays visible. The cause is still under investigation; a hidden window stops receiving interface updates.
- **Process and I/O detail:** process CPU usage is the decaying average reported by `ps`. Network and disk rates are system-wide, with no per-process or per-interface breakdown.
- **Distribution:** Developer ID signing, notarization, and a Homebrew cask are not implemented.

## Contributing

Bug reports, model compatibility reports, and pull requests are welcome. Open an issue in this repository with your Mac model and chip, macOS version, macmon version (`macmon --version`), steps to reproduce, and any relevant error output. Remove private information from logs or screenshots before sharing.

For code changes, run the checks from the [Development](#development) table (`npm test`, `npm run build`, `node rendercheck.mjs`, and `npm run native:check` when touching `native/`). Keep Swift and JavaScript alert rules in sync. If you change the snapshot contract, update both the native collector and the React interface.

## Troubleshooting

- **A page saying "UI not found"**: the interface is not built; use `npm run native:build` (or `npm run build` before `native:dev`).
- **"macmon was not found"**: install it with `brew install macmon` (the build copies it into the app).
- **"Stale" badge**: macmon stopped sending frames for more than 5 seconds (or 2.5 update intervals, if that is longer).
- **No notifications**: allow them in System Settings › Notifications › MacResMon, and use "Send test notification" in Settings. They are not available when started with `npm run native:dev`.
- **The menu-bar item is missing**: it is switched off in Settings, or the menu bar is full (the item can hide behind the notch or other icons).
- **The build prints `ld: warning: search path '/Library/Developer/CommandLineTools/Developer/...' not found`** (five lines): the app is built correctly, but SwiftPM 6's default build engine adds the platform folders of a full Xcode (`<developer dir>/Developer/Library/Frameworks` and `<developer dir>/Developer/usr/lib`) and with only the Command Line Tools those two folders do not exist. Create them once (admin password; the folders are lost when the Command Line Tools are updated, then run it again): `sudo mkdir -p /Library/Developer/CommandLineTools/Developer/Library/Frameworks /Library/Developer/CommandLineTools/Developer/usr/lib`. Installing full Xcode does the same. Do not silence the linker (`-Xlinker -w`) and do not use the deprecated `--build-system native`.
- **The build fails**: check that `macmon` is installed (`which macmon`), Swift works (`swift --version`) and `npm install` has been run.

## Publishing on GitHub

<details>
<summary>Repository description, topics, social preview, and releases</summary>

Use `MacResMon` as the repository name. In **About → Edit repository metadata**, set this description:

```text
Free, open-source macOS system monitor for Apple Silicon. Track CPU/GPU usage, temperatures, fan speed (RPM), memory, power, battery, disk and network, with a live menu bar readout. Swift + React, no sudo.
```

Add these topics individually in the same editor:

```text
macos apple-silicon system-monitor hardware-monitor performance-monitor
menu-bar temperature-monitor fan-speed cpu-monitor gpu-monitor
memory-monitor power-monitor battery-monitor swift react wkwebview macmon
```

GitHub's default repository search uses the name, description, and topics; README content is searchable with `in:readme`. These settings must be applied on GitHub separately from this file. See [GitHub's repository search documentation](https://docs.github.com/en/search-github/searching-on-github/searching-for-repositories). Only set a website URL if the project has a website.

For a shared-link preview, upload a 1280 × 640 PNG or JPG under 1 MB in **Settings → General → Social preview**. Include the MacResMon name, “macOS System Monitor for Apple Silicon,” and a readable dashboard crop on a solid background. Label demo readings. See [GitHub's social preview documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).

Enable Issues for bug and model compatibility reports. Publish source with the MIT license and both README screenshots; keep generated build folders out of commits. For downloadable builds, attach the DMG to a versioned GitHub Release and document supported hardware, build provenance, and signing/notarization status. Add a README download link once the release asset is available.

</details>

## Credits and license

Sensor data comes from [macmon](https://github.com/vladkens/macmon) by vladkens (MIT), which is bundled in the app together with its license notice. This project is released under the [MIT License](LICENSE).
