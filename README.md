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

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/reports-dark.png">
  <img src="docs/reports-light.png" alt="MacResMon Reports tab with energy, cost at the electricity price, a table of days and a log of temperature spikes with peak time and duration" width="900">
</picture>

*The Reports tab (demo data): power use and cost per day, and the temperature spike log. [Light screenshot](docs/reports-light.png) · [Dark screenshot](docs/reports-dark.png).*

[Features](#features) · [Build and run](#build-and-run) · [FAQ](#faq) · [Troubleshooting](#troubleshooting) · [Contributing](#contributing)

## Why MacResMon?

When your MacBook Pro gets hot or its fans spin up, check temperatures, fan RPM, CPU and GPU load, power draw, and the busiest processes together. Keep the live CPU and temperature readout in the macOS menu bar, then open the dashboard for a closer look.

MacResMon monitors your Mac; it does not change fan speeds, CPU settings, or thermal limits.

## Features

- **Cooling**: a spinning rotor per fan (speed follows RPM), one filled graph with a line per fan, and a live legend with RPM and % of maximum
- **CPU, GPU, memory**: load rings, thermometers in °C or °F, swap, 60-sample trends (one minute at the default interval), and a load column for every CPU core, grouped by Performance and Efficiency cluster
- **Power and battery**: whole-system watts, chip (CPU + GPU + ANE + RAM), CPU and GPU power, charge level, charging state, time left and power adapter wattage
- **Header**: **Dashboard / Reports** tabs, a power-source badge ("AC power 80%", with charging or draining watts and time left on battery), a **This Mac** button that opens the chip, macOS version, core counts per tier, GPU cores, and memory and disk usage, a **gear** button that opens Settings, and the light/dark switch. Hover the badge, the button or a core column for details
- **Top processes**: top 5 by CPU and by memory, to answer "what is heating the Mac?"
- **Storage and network**: free space, disk read/write speed, download and upload in MB/s and Mbps
- **Menu bar**: a fan icon with a live readout of the parts you choose in Settings (CPU % and temperature by default; while an alert is active it shows `⚠︎` and turns orange, or red for a critical alert, and it blinks for a few seconds when a new alert appears, so you notice it with the window closed) and a menu with the details, "Open MacResMon" and Settings
- **Alerts and notifications**: alert chips in the window header (the two most severe, plus "+N") and a macOS notification when CPU or GPU reaches 90 °C, a fan reaches 95% of its maximum speed, memory is 90% full, the battery is at 10% or the disk is almost full; they also arrive while the window is closed
- **Reports** (the Reports tab): a log kept between launches of power use per day (energy, average and peak watts, cost at your electricity price) and of temperature spikes (every time CPU or GPU reached 90 °C: start, sensor, peak, when the peak was reached, how long the temperature stayed within 1 °C of it, and how long the whole spike lasted), with a period filter (7, 14, 30, 90 days or all), CSV export of both tables and a reset
- **Settings** (⌘, or the gear button in the header), in sections: launch at login (starts hidden in the menu bar), keep running when the window is closed; **Menu bar** with a checkbox for each part of the readout (CPU load, CPU temperature, GPU load, GPU temperature, memory used, fan speed, power, battery level); notifications (with a test button); temperature unit and update interval (0.5, 1, 2 or 5 seconds; 1 by default); electricity price per kWh and a button that erases the reports. Every setting is saved at once and restored at the next launch, together with the window positions, the theme, the selected tab and the report period
- **Window and login**: the red close button hides the window and the Dock icon while the menu-bar item keeps monitoring; with Launch at login the app starts hidden
- Light and dark theme (remembered), and an app icon

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

The build packs the interface, the Swift app and a copy of `macmon` into one app of about 4 MB. Copy it to `/Applications` if you like, and rebuild with the same command after changing any code.

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

The result is `native/build/MacResMon.dmg`. Newer macOS versions print a warning that `hdiutil create` is deprecated; it still works. Apple's replacement, `diskutil image`, may not exist on older macOS versions, so the steps above use `hdiutil`. Where `diskutil image` is available you can use it instead of the `hdiutil create` line (same folder; delete an old `MacResMon.dmg` first, it does not overwrite):

```bash
diskutil image create from --format UDZO --volumeName MacResMon native/build/dmg native/build/MacResMon.dmg
```

The image carries the same ad-hoc signature as the app, so the first-launch warning described above applies on other Macs.

## Using the app

- **Window**: ⌘R reloads the interface. With "Keep running in the menu bar" on (the default) the red close button hides the window and the Dock icon, and the app keeps monitoring from the menu bar; choose "Open MacResMon" in the menu-bar menu to bring both back. With the option off, closing quits the app; with the menu-bar item hidden, the window stays in the Dock instead. Quit with ⌘Q or from the menu-bar item.
- **Menu bar**: click the fan icon for CPU, GPU, memory, fans, power, battery and active alerts, or to open the window or Settings. What the icon's readout shows is chosen under Menu bar in Settings.
- **Notifications**: macOS asks for permission the first time one is needed (or when you press "Send test notification" in Settings).
- **Launch at login**: switch it on in Settings. The app then starts without a window or Dock icon, only the menu-bar item (unless the menu-bar item is switched off, then the window opens); `MacResMon --background` does the same by hand. macOS may ask you to approve it in System Settings › General › Login Items; Settings has a button that opens it.
- **Reports**: switch to the Reports tab in the header. It records while the app runs, also with the window hidden or closed to the menu bar, but not while the app is quit. Energy is the whole-Mac power reported by the sensors (`sys_power`) times the time it covers; a gap longer than 10 s (sleep) adds at most 10 s. Cost is energy times the price per kWh from Settings and is calculated when you look, so changing the price re-costs every day. A day starts at local midnight. "Export power CSV" and "Export spikes CSV" save the rows of the selected period (a save dialog opens); "Reset" (or "Reset reports…" in Settings) erases everything after a confirmation, so export first if you need the data.
- The temperature unit (°C, °F or follow the system region) is set in Settings only and applies to the window, the menu bar and notifications.

## How it works

```
macmon (child process)       ┐
ps · pmset · df              ├─> Swift Sampler/Monitor ──(1 s by default)──> window.__nativeHub ──> React UI in a WKWebView
getifaddrs · IOKit (counters)┘        │
                                      ├─> menu-bar item, alert notifications
                                      └─> reports.json (power per day, temperature spikes) <─> Reports tab
```

The Swift side reads [macmon](https://github.com/vladkens/macmon) (CPU, GPU, power, temperatures, fans, memory), a few macOS tools (processes, battery, disk space) and direct system counters (network, disk I/O). Once per update interval (1 second by default, set in Settings) it builds one snapshot, keeps the last 60 samples, feeds the menu bar and notifications, and pushes the snapshot into the page. Each tick also feeds the report log (see `ReportStore`), which is saved to `~/Library/Application Support/MacResMon/reports.json` every 30 seconds, when a spike starts or ends, and on quit (at most the newest 5000 spikes are kept; days are kept until you reset). The Reports tab asks the app for the log through `window.__native.request(...)` (the page's only way to call the app: `reports.get`, the CSV exports and `reports.reset`, `settings.open` for the gear button, and `state.set` to remember the theme, tab and report period) and the app answers, opens the save dialog for CSV export and asks before erasing. The interface is a small React app drawn with plain SVG (no chart library), built with Vite and bundled into the app; the page is only fed while the window is visible.

```
native/   Swift package: MonitorCore (parsers, snapshot, alert rules, report log and CSV) · MacResMon (window, menu bar,
          notifications, settings, report storage) · CoreChecks (unit checks) · build.sh · Tools/make-icon
src/      the React interface (cards, hooks, header alert chips, Reports tab)
docs/     README screenshots (demo readings, not real data)
```

## Development

| Command | What it does |
| --- | --- |
| `npm run native:build` | builds the interface and the app |
| `npm run build && npm run native:dev` | runs the app without packaging (uses `dist/` and the `macmon` in `/opt/homebrew/bin` or `/usr/local/bin`; notifications and launch at login need the real app) |
| `npm test` | interface logic: formatters, alert rules and report rows |
| `npm run native:check` | the Swift parsers, snapshot builder, alert rules and report log (no Xcode needed) |
| `node rendercheck.mjs` | renders every component server-side as a smoke test |
| `npm run native:icon` | redraws the app icon |

Checks without looking at the screen: run the app binary with `--screenshot FILE` (PNG of the window), `--screenshot-settings FILE` or `--dump-status` (prints the menu-bar title and rows); `--background` starts it like a login item. Environment variables: `MACMON_BIN` (path to macmon) and `MONITOR_DIST` (path to a built interface).

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
No. The app has no server and makes no network connections; everything stays on your Mac. The only file it writes is the report log, `~/Library/Application Support/MacResMon/reports.json`; delete it or use Reset to erase it.

**Why is the interface built with web technology?**
It keeps the charts easy to change and to preview; the native Swift shell does everything that needs the system (sensors, menu bar, notifications, launch at login). Node is only used to build the interface.

**Which Macs has it been tested on?**
It was developed and tested on a single Apple Silicon MacBook Pro. Reports for other models are welcome as issues.

## Known limitations

- **Sensor coverage:** Apple Silicon only; readings vary by hardware and macmon support. There is no fan control.
- **Visible-window memory use:** the WKWebView WebContent process has shown memory growth while the dashboard stays visible. The cause is still under investigation; a hidden window stops receiving interface updates.
- **Hidden login start:** the app recognizes a login launch from the launch event macOS sends to login items; this was not tested through a real log-out and log-in, so if the window still opens at login, use `--background` in a LaunchAgent and open an issue.
- **Reports:** energy comes from the system power sensor and counts only while the app runs; spikes use the same 90 °C limit as the alerts (not configurable); the log keeps the newest 5000 spikes. A spike still in progress when the app crashes is not saved.
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

Enable Issues for bug and model compatibility reports. Publish source with the MIT license and the README screenshots in `docs/`; keep generated build folders out of commits. For downloadable builds, attach the DMG to a versioned GitHub Release and document supported hardware, build provenance, and signing/notarization status. Add a README download link once the release asset is available.

</details>

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=proars/MacResMon&type=Date)](https://star-history.com/#proars/MacResMon&Date)

## Credits and license

Sensor data comes from [macmon](https://github.com/vladkens/macmon) by vladkens (MIT), which is bundled in the app together with its license notice. This project is released under the [MIT License](LICENSE).
