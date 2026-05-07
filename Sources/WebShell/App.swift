import SwiftUI
import AppKit

@main
struct WindowedApp: App {
    @AppStorage("savedURL") private var savedURL: String = ""
    @AppStorage("savedName") private var savedName: String = ""
    @State private var showURLSheet: Bool = false

    init() {
        // Load icon from the active preset on launch.
        if let data = UserDefaults.standard.data(forKey: "urlPresets"),
           let list = try? JSONDecoder().decode([URLEntry].self, from: data),
           let entry = list.first(where: { $0.url == savedURL }),
           let path = entry.iconPath, !path.isEmpty,
           let img = NSImage(contentsOfFile: path) {
            NSApplication.shared.applicationIconImage = img
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(savedURL: $savedURL, savedName: $savedName, showURLSheet: $showURLSheet)
                .onAppear {
                    if savedURL.isEmpty {
                        showURLSheet = true
                    }
                }
                .sheet(isPresented: $showURLSheet) {
                    URLInputSheet(savedURL: $savedURL, savedName: $savedName, isPresented: $showURLSheet)
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Change URL…") {
                    showURLSheet = true
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
}
