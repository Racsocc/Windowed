# Windowed

[中文版](README_CN.md)

A lightweight macOS wrapper app that turns any web page into a native desktop window. Point it at a URL, and you get a standalone app with its own Dock icon, window, and title — no browser chrome, no tabs.

Originally built to wrap [Hermes WebUI](https://github.com/nesquena/hermes-webui), but works with any URL.

## Features

- **Custom display name** — shown in the window title bar
- **URL history** — remembers up to 10 recent URLs with pin support for favorites
- **Custom app icon** — pick any local image as the Dock/Stage Manager icon
- **Local service auto-start** — attach a `start` command to local URL presets and launch services automatically
- **Optional stop-on-close per preset** — enable stopping a service when the window closes and provide a matching `stop` command
- **Native web dialog support** — supports `alert()`, `confirm()`, and `prompt()` for delete confirmations and input flows
- **Zero dependencies** — pure SwiftUI + WebKit, no frameworks, no bundler
- **Self-contained** — single .app, no install step

## Usage

1. Launch `Windowed.app`
2. Enter a display name (optional) and URL
3. The web page loads in a native macOS window
4. Use `⌘U` or the gear button to change URL anytime

### Local Service Presets

If your target is a local service such as `http://127.0.0.1:18789/chat?session=main`, you can also configure:

- **Start command** — for example `~/hermes-webui/ctl.sh start`
- **Stop service when window closes** — enabled per preset, off by default
- **Stop command** — for example `~/hermes-webui/ctl.sh stop`

Windowed will try to start the service when that preset opens, and only run the stop command on window close or app termination when you explicitly enable it.

### Custom Icon

In the settings sheet, click **Choose Icon…** and pick a `.png`, `.jpg`, `.icns`, or `.tiff` file. The icon persists across launches. Click **Remove** to revert to default.

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
    ├── App.swift              # App entry point, window setup
    ├── ContentView.swift      # Main view, toolbar, URL state, service lifecycle
    ├── ServiceStarter.swift   # Local service start, health checks, stop dispatch
    ├── WebView.swift          # WKWebView wrapper with native JS dialog support
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
│  ├─ Loads saved URL/name/icon from storage  │
│  ├─ Shows URLInputSheet on first launch     │
│  └─ WindowGroup → ContentView               │
├─────────────────────────────────────────────┤
│  ContentView                                │
│  ├─ Toolbar: title | gear | reload          │
│  ├─ Empty state → Set URL button            │
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
│  └─ Updates window title from page title    │
├─────────────────────────────────────────────┤
│  URLInputSheet                              │
│  ├─ Display name + URL input                │
│  ├─ History list (up to 10, with pinning)   │
│  ├─ Start / stop command settings           │
│  └─ Icon picker (NSOpenPanel → bundle)      │
└─────────────────────────────────────────────┘
```

## License

Personal use. Do whatever you want with it.
