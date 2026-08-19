import SwiftUI
import AppKit

enum WindowedScene {
    static let browser = "browser"
}

final class WindowedAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        WindowSessionRegistry.shared.beginTermination()
        return .terminateNow
    }
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
    @NSApplicationDelegateAdaptor(WindowedAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: WindowedScene.browser, for: WindowConfig.self) { $windowConfig in
            ContentView(windowConfig: $windowConfig)
        } defaultValue: {
            WindowRestoreCoordinator.shared.initialWindowConfig
        }
        .windowStyle(.automatic)
        .commands {
            WindowedCommands()
        }
    }
}
