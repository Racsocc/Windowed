import SwiftUI

struct ContentView: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var showURLSheet: Bool
    @State private var currentURL: String = ""

    var body: some View {
        Group {
            if currentURL.isEmpty {
                emptyState
            } else {
                WebView(urlString: currentURL)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showURLSheet = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("Change URL")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    currentURL = savedURL
                } label: {
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)

            Text("No URL Configured")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Set URL…") {
                showURLSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Title

    private var displayTitle: String {
        if !savedName.isEmpty {
            return savedName
        }
        if let u = URL(string: currentURL), let host = u.host {
            return host + (u.path == "/" ? "" : u.path)
        }
        return currentURL.isEmpty ? "Windowed" : currentURL
    }
}
