# Windowed

[中文版](README_CN.md)

A lightweight macOS wrapper app that turns any web page into a native desktop window. Point it at a URL, and you get a standalone app with its own Dock icon, window, and title — no browser chrome, no tabs.

Originally built to wrap [Hermes WebUI](https://github.com/nesquena/hermes-webui), but works with any URL.

## Features

- **Custom display name** — shown in the window title bar
- **URL history** — remembers up to 5 recent URLs, switch with one click
- **Custom app icon** — pick any local image as the Dock/Stage Manager icon
- **Zero dependencies** — pure SwiftUI + WebKit, no frameworks, no bundler
- **Self-contained** — single .app, no install step

## Usage

1. Launch `Windowed.app`
2. Enter a display name (optional) and URL
3. The web page loads in a native macOS window
4. Use `⌘U` or the gear button to change URL anytime

### Custom Icon

In the settings sheet, click **Set App Icon** and pick a `.png`, `.jpg`, `.icns`, or `.tiff` file. The icon persists across launches. Click **Remove Icon** to revert to default.

### Sharing with Others

The app is unsigned. Recipients need to:

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

# Create .app bundle
mkdir -p Windowed.app/Contents/MacOS Windowed.app/Contents/Resources
cp .build/release/Windowed Windowed.app/Contents/MacOS/
cp Info.plist Windowed.app/Contents/

# Optional: add custom icon
cp Windowed.icns Windowed.app/Contents/Resources/

# Move to Applications
mv Windowed.app /Applications/

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
└── Sources/WebShell/          # Source code
    ├── App.swift              # App entry point, window setup
    ├── ContentView.swift      # Main view, toolbar, URL state
    ├── WebView.swift          # WKWebView wrapper (NSViewRepresentable)
    └── URLInputSheet.swift    # Settings sheet: URL input, name, icon, history
```

## Tech Stack

- **Swift 6.3** + **SwiftUI** — app framework
- **WKWebView** (WebKit) — web rendering
- **NSViewRepresentable** — bridges WKWebView into SwiftUI
- **UserDefaults** — persists URL, name, icon path, history
- **NSOpenPanel** — file picker for custom icons

No third-party dependencies. One `Package.swift`, four source files.

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
│  └─ Loaded state → WebView                  │
├─────────────────────────────────────────────┤
│  WebView (NSViewRepresentable)              │
│  ├─ Wraps WKWebView for SwiftUI             │
│  ├─ Handles navigation, errors              │
│  └─ Updates window title from page title    │
├─────────────────────────────────────────────┤
│  URLInputSheet                              │
│  ├─ Display name + URL input                │
│  ├─ History list (up to 5)                  │
│  └─ Icon picker (NSOpenPanel → bundle)      │
└─────────────────────────────────────────────┘
```

## License

Personal use. Do whatever you want with it.
