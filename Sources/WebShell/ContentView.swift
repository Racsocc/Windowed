import SwiftUI

struct ContentView: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var showURLSheet: Bool
    @AppStorage("autoStartWebUI") private var autoStartWebUI: Bool = false
    @StateObject private var webuiStarter = WebUIStarter()
    @State private var currentURL: String = ""
    @State private var webuiReady: Bool = false  // tracks whether we've finished the start attempt

    var body: some View {
        Group {
            if currentURL.isEmpty {
                emptyState
            } else if shouldWaitForWebUI && !webuiReady {
                loadingState
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
                tryStartWebUIIfNeeded()
            }
        }
        .onChange(of: savedURL) { _, newValue in
            if !newValue.isEmpty {
                currentURL = newValue
                webuiReady = false
                tryStartWebUIIfNeeded()
            }
        }
    }

    // MARK: - Loading State (WebUI starting)

    private var shouldWaitForWebUI: Bool {
        autoStartWebUI && WebUIStarter.isLocalWebUI(currentURL)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            switch webuiStarter.status {
            case .idle, .starting:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("Starting WebUI service…")
                    .font(.callout)
                    .foregroundStyle(.secondary)

            case .ready:
                // Brief flash — onAppear will flip webuiReady almost immediately.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("Ready")
                    .foregroundStyle(.secondary)

            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("WebUI failed to start")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Load anyway") {
                    webuiReady = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(webuiStarter.$status) { newStatus in
            if newStatus == .ready {
                // Small delay so the UI can show the checkmark briefly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    webuiReady = true
                }
            }
        }
    }

    private func tryStartWebUIIfNeeded() {
        guard shouldWaitForWebUI else {
            webuiReady = true
            return
        }
        webuiStarter.startIfNeeded()
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
