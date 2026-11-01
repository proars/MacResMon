# MacResMon development notes

For people who build, change or package the app. The user guide is the [README](../README.md).

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
docs/     README screenshots (demo readings, not real data) and these notes
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

## Building

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

The image carries the same ad-hoc signature as the app, so the first-launch warning described in the [README](../README.md#download-and-install) applies on other Macs.

### Release

Build the app and the `.dmg`, then attach the image to a GitHub release. Keep the file name `MacResMon.dmg`: the README download links point to `releases/latest/download/MacResMon.dmg`. Do not rebuild between making the image and publishing it (the build deletes `native/build/` and the checksum changes).

```bash
shasum -a 256 native/build/MacResMon.dmg
gh release create vX.Y.Z native/build/MacResMon.dmg --title "MacResMon X.Y.Z" \
  --notes "Apple Silicon, macOS 13+. Ad-hoc signed, not notarized. SHA-256: <checksum>"
```
