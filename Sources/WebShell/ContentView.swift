import SwiftUI

struct ContentView: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var showURLSheet: Bool
    @State private var currentURL: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if currentURL.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No URL configured")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Button("Set URL") {
                        showURLSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WebView(urlString: currentURL)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showURLSheet = true
                }) {
                    Image(systemName: "gear")
                }
                .help("Change URL")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    currentURL = savedURL
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload")
                .disabled(currentURL.isEmpty)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            if !savedURL.isEmpty {
                currentURL = savedURL
            }
        }
        .onChange(of: savedURL) { _, newValue in
            if !newValue.isEmpty {
                currentURL = newValue
            }
        }
    }

    private var displayTitle: String {
        if !savedName.isEmpty {
            return savedName
        }
        if let u = URL(string: currentURL), let host = u.host {
            return host + (u.path == "/" ? "" : u.path)
        }
        return currentURL.isEmpty ? "WebShell" : currentURL
    }
}
