import SwiftUI

struct ContentView: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var showURLSheet: Bool
    @StateObject private var serviceStarter = ServiceStarter()
    @State private var currentURL: String = ""
    @State private var serviceReady: Bool = false
    @State private var reloadToken: UUID = UUID()
    @State private var settingsHasChanges: Bool = false
    @State private var showDiscardAlert: Bool = false

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
        ZStack {
            // Main content
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

            // Settings overlay
            if showURLSheet {
                // Background overlay — captures taps
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        handleBackgroundTap()
                    }

                // Settings panel
                URLInputSheet(
                    savedURL: $savedURL,
                    savedName: $savedName,
                    isPresented: $showURLSheet,
                    hasChanges: $settingsHasChanges
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showURLSheet)
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
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                showURLSheet = false
                settingsHasChanges = false
            }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes.")
        }
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

    // MARK: - Background Tap

    private func handleBackgroundTap() {
        if settingsHasChanges {
            showDiscardAlert = true
        } else {
            showURLSheet = false
        }
    }

    // MARK: - Loading State

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
            serviceReady = false
            serviceStarter.reset()
            serviceStarter.start(command: cmd, healthURL: currentURL)
        } else {
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
