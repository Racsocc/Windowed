import SwiftUI

struct ContentView: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var showURLSheet: Bool
    @StateObject private var serviceStarter = ServiceStarter()
    @State private var currentURL: String = ""
    @State private var serviceReady: Bool = false
    @State private var reloadToken: UUID = UUID()  // forces WebView recreation

    private var startCommand: String? {
        guard let data = UserDefaults.standard.data(forKey: "urlPresets"),
              let list = try? JSONDecoder().decode([URLEntry].self, from: data),
              let entry = list.first(where: { $0.url == savedURL }),
              let cmd = entry.startCommand, !cmd.isEmpty else {
            return nil
        }
        return cmd
    }

    private var hasStartCommand: Bool {
        startCommand != nil && ServiceStarter.isLocal(savedURL)
    }

    var body: some View {
        Group {
            if currentURL.isEmpty {
                emptyState
            } else if hasStartCommand && !serviceReady {
                loadingState
            } else {
                WebView(urlString: currentURL)
                    .id(reloadToken)
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
                    performRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(hasStartCommand ? "Restart service & reload" : "Reload")
                .disabled(currentURL.isEmpty)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            if !savedURL.isEmpty {
                currentURL = savedURL
                tryStartService()
            }
        }
        .onChange(of: savedURL) { _, newValue in
            if !newValue.isEmpty {
                currentURL = newValue
                serviceReady = false
                serviceStarter.reset()
                tryStartService()
            }
        }
    }

    // MARK: - Loading State (service starting)

    private var loadingState: some View {
        VStack(spacing: 16) {
            switch serviceStarter.status {
            case .idle, .starting:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("Starting service…")
                    .font(.callout)
                    .foregroundStyle(.secondary)

            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("Ready")
                    .foregroundStyle(.secondary)

            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("Service failed to start")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                Button("Load anyway") {
                    serviceReady = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(serviceStarter.$status) { newStatus in
            if newStatus == .ready {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    serviceReady = true
                }
            }
        }
    }

    // MARK: - Service Control

    private func tryStartService() {
        guard let cmd = startCommand, ServiceStarter.isLocal(currentURL) else {
            serviceReady = true
            return
        }
        serviceStarter.start(command: cmd, healthURL: currentURL)
    }

    private func performRefresh() {
        if hasStartCommand, let cmd = startCommand {
            // Re-run service, then reload page.
            serviceReady = false
            serviceStarter.reset()
            serviceStarter.start(command: cmd, healthURL: currentURL)
        } else {
            // Just reload the WebView.
            reloadToken = UUID()
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
