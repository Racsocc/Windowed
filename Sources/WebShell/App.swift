import SwiftUI
import AppKit

@main
struct WindowedApp: App {
    @AppStorage("savedURL") private var savedURL: String = ""
    @AppStorage("savedName") private var savedName: String = ""
    @State private var showURLSheet: Bool = false

    init() {
        // Load custom icon on launch
        if let path = UserDefaults.standard.string(forKey: "customIconPath"),
           !path.isEmpty, let img = NSImage(contentsOfFile: path) {
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
        .commands {
            CommandGroup(after: .newItem) {
                Button("Change URL...") {
                    showURLSheet = true
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
}
