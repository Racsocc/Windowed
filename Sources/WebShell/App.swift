import SwiftUI
import AppKit

enum WindowedScene {
    static let browser = "browser"
}

extension Notification.Name {
    static let windowedOpenSettingsRequested = Notification.Name("windowedOpenSettingsRequested")
}

struct WindowedCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: WindowedScene.browser, value: WindowConfig())
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Button("Change URL…") {
                NotificationCenter.default.post(name: .windowedOpenSettingsRequested, object: nil)
            }
            .keyboardShortcut("u", modifiers: .command)
        }
    }
}

@main
struct WindowedApp: App {
    var body: some Scene {
        WindowGroup(id: WindowedScene.browser, for: WindowConfig.self) { $windowConfig in
            ContentView(windowConfig: $windowConfig)
        } defaultValue: {
            WindowConfigStore.loadLastUsed() ?? WindowConfig()
        }
        .windowStyle(.automatic)
        .commands {
            WindowedCommands()
        }
    }
}
