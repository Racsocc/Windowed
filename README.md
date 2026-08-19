# Windowed

[中文版](README_CN.md)

A lightweight macOS wrapper app that turns any web page into a native desktop window. Point it at a URL, and you get a standalone app with its own Dock icon, window, and title — no browser chrome, no tabs.

Originally built to wrap [Hermes WebUI](https://github.com/nesquena/hermes-webui), but works with any URL.

## Features

- **Single-app multi-window** — open multiple independent web windows under one Dock icon, with `⌘N`
- **Restore last window session** — reopen every configured window from the previous session on launch, and fall back to a blank setup window when nothing is saved
- **Custom display name** — shown in the window title bar
- **URL history** — remembers up to 20 non-pinned URLs, while pinned favorites remain unlimited
- **Custom preset icon** — pick any local image as a visual marker in the preset list
- **Local service auto-start** — attach a `start` command to local URL presets and launch services automatically
- **Optional stop-on-close per preset** — enable stopping a service when the window closes and provide a matching `stop` command
- **Native web dialog support** — supports `alert()`, `confirm()`, and `prompt()` for delete confirmations and input flows
- **Web file upload support** — supports file, image, and multi-file selection with the native Finder panel
- **Zero dependencies** — pure SwiftUI + WebKit, no frameworks, no bundler
- **Self-contained** — single .app, no install step

## Usage

1. Launch `Windowed.app`
2. Enter a display name (optional) and URL
3. The web page loads in a native macOS window
4. Use `⌘U` or the gear button to open a blank setup sheet, then save to replace the current window contents
5. Press `⌘N` to open a new blank window

### Multi-window

- `⌘N` opens a new independent window
- Each window has its own URL, display name, and service lifecycle
- Clicking a history preset opens it in a new window by default
- The setup sheet always starts blank; only the History edit button loads an existing preset into edit mode

### Launch behavior

- On launch, Windowed first tries to restore every configured window from the previous session
- Blank setup windows and unsaved drafts are not restored
- If there is no saved session, it opens a blank setup window instead
- Blank setup windows size themselves to about `70%` of the visible screen width and `80%` of the visible screen height

### Local Service Presets

If your target is a local service such as `http://127.0.0.1:18789/chat?session=main`, you can also configure:

- **Start command** — for example `~/hermes-webui/ctl.sh start`
- **Stop service when window closes** — enabled per preset, off by default
- **Stop command** — for example `~/hermes-webui/ctl.sh stop`

Windowed will try to start the service when that preset opens, including when a saved window is restored on the next launch. It only runs the stop command on window close or app termination when that preset explicitly enables it.

### Custom Icon

In the settings sheet, click **Choose Icon…** and pick a `.png`, `.jpg`, `.icns`, or `.tiff` file. The icon persists as a visual marker for that preset in the history list across launches. The Dock icon stays fixed as the default `Windowed` app icon and does not change per window or preset. Click **Remove** to clear the preset icon.

### Can't Open Because Apple Cannot Check It for Malicious Software

Because the app is not signed and notarized with an Apple Developer certificate, recipients may need to:

```bash
# Remove quarantine flag + ad-hoc sign
xattr -cr /Applications/Windowed.app
codesign --force --deep --sign - /Applications/Windowed.app
```

Or right-click → Open on first launch.

## Build

Requires macOS 14+ and Xcode Command Line Tools.

```bash
# Build release
cd /path/to/Windowed
swift build -c release

# If SwiftPM hits sandbox permission issues, use
swift build -c release --disable-sandbox

# Create .app bundle
mkdir -p dist/Windowed.app/Contents/MacOS dist/Windowed.app/Contents/Resources
cp .build/release/Windowed dist/Windowed.app/Contents/MacOS/
cp Info.plist dist/Windowed.app/Contents/

# Optional: add custom icon
cp Windowed.icns dist/Windowed.app/Contents/Resources/

# Optional: ad-hoc sign
codesign --force --deep --sign - dist/Windowed.app

# Move to Applications
mv dist/Windowed.app /Applications/

# Clean build cache
rm -rf .build
```

## Project Structure

```
Windowed/
├── Package.swift              # Swift Package Manager config
├── Info.plist                 # App bundle metadata
├── Windowed.icns              # Default app icon
├── README.md
├── README_CN.md               # Chinese guide
└── Sources/WebShell/          # Source code
    ├── App.swift              # App entry point, multi-window scene setup
    ├── ContentView.swift      # Main view, per-window URL state, service lifecycle
    ├── ServiceStarter.swift   # Local service start, health checks, stop dispatch
    ├── WebView.swift          # WKWebView wrapper with JS dialogs and file upload support
    ├── WindowConfig.swift     # Window instance model
    └── URLInputSheet.swift    # Settings sheet: URL, name, icon, history, start/stop commands
```

## Tech Stack

- **Swift 6.3** + **SwiftUI** — app framework
- **WKWebView** (WebKit) — web rendering
- **NSViewRepresentable** — bridges WKWebView into SwiftUI
- **UserDefaults** — persists URL, name, icon path, history, and service settings
- **NSOpenPanel** — file picker for custom icons
- **Process / Timer / URLSession** — launches local services, polls health, runs stop commands

No third-party dependencies. One `Package.swift`, five source files.

## Architecture

```
┌─────────────────────────────────────────────┐
│  WindowedApp (@main)                        │
│  ├─ WindowGroup(for: WindowConfig)          │
│  ├─ Supports multiple windows               │
│  └─ ContentView with per-window state       │
├─────────────────────────────────────────────┤
│  ContentView                                │
│  ├─ Toolbar: title | gear | reload          │
│  ├─ Per-window URL / name / service state   │
│  ├─ Local presets → ServiceStarter          │
│  └─ Loaded state → WebView                  │
├─────────────────────────────────────────────┤
│  ServiceStarter                             │
│  ├─ Runs start / stop commands              │
│  ├─ Polls local health endpoints            │
│  └─ Prevents duplicate launches             │
├─────────────────────────────────────────────┤
│  WebView (NSViewRepresentable)              │
│  ├─ Wraps WKWebView for SwiftUI             │
│  ├─ Handles navigation, errors, JS dialogs  │
│  ├─ Handles web file upload                 │
│  └─ Updates window title from page title    │
├─────────────────────────────────────────────┤
│  URLInputSheet                              │
│  ├─ Display name + URL input                │
│  ├─ History list (20 regular, unlimited pinned) │
│  ├─ Start / stop command settings           │
│  └─ Icon picker (NSOpenPanel → bundle)      │
└─────────────────────────────────────────────┘
```

## License

Personal use. Do whatever you want with it.
