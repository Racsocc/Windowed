import SwiftUI
import AppKit

struct ContentView: View {
    @Binding var windowConfig: WindowConfig
    @Environment(\.openWindow) private var openWindow
    @StateObject private var serviceStarter = ServiceStarter()
    @State private var currentURL: String = ""
    @State private var showURLSheet: Bool = false
    @State private var serviceReady: Bool = false
    @State private var reloadToken: UUID = UUID()
    @State private var settingsHasChanges: Bool = false
    @State private var showDiscardAlert: Bool = false
    @State private var hostWindow: NSWindow?
    @State private var hasAppliedInitialWindowSize: Bool = false

    private var startCommand: String? {
        guard let cmd = windowConfig.startCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cmd.isEmpty else { return nil }
        return cmd
    }

    private var stopCommand: String? {
        guard let cmd = windowConfig.stopCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cmd.isEmpty else { return nil }
        return cmd
    }

    private var shouldStopOnClose: Bool {
        windowConfig.stopOnClose
    }

    private var hasStartCommand: Bool {
        startCommand != nil && ServiceStarter.isLocal(currentURL)
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
                    windowConfig: $windowConfig,
                    isPresented: $showURLSheet,
                    hasChanges: $settingsHasChanges,
                    openInNewWindow: openNewWindow
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .background(WindowAccessor(window: $hostWindow))
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
        .frame(minWidth: 800, minHeight: currentURL.isEmpty ? 800 : 500)
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
            WindowRestoreCoordinator.shared.restoreAdditionalWindows(openWindow: openNewWindow)
            WindowSessionRegistry.shared.upsert(windowConfig)
            currentURL = windowConfig.url
            if currentURL.isEmpty {
                showURLSheet = true
            } else {
                tryStartService()
                persistAsLastUsedIfNeeded()
            }
        }
        .onChange(of: hostWindow?.windowNumber ?? -1) { _, _ in
            applyInitialWindowSizeIfNeeded()
        }
        .onChange(of: showURLSheet) { _, isShowing in
            guard isShowing else { return }
            ensureSettingsSheetFits()
        }
        .onReceive(NotificationCenter.default.publisher(for: .windowedOpenSettingsRequested)) { _ in
            guard hostWindow?.isKeyWindow == true else { return }
            showURLSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window == hostWindow else {
                return
            }
            persistAsLastUsedIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window == hostWindow else {
                return
            }
            WindowSessionRegistry.shared.remove(id: windowConfig.id)
            persistAsLastUsedIfNeeded()
            handleWindowClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            persistAsLastUsedIfNeeded()
            handleWindowClose()
        }
        .onChange(of: windowConfig) { oldValue, newValue in
            let urlChanged = oldValue.url != newValue.url
            let commandChanged = oldValue.startCommand != newValue.startCommand
                || oldValue.stopCommand != newValue.stopCommand
                || oldValue.stopOnClose != newValue.stopOnClose

            guard urlChanged || commandChanged else { return }

            if urlChanged {
                serviceStarter.reset(runStopCommand: oldValue.stopOnClose)
            }

            currentURL = newValue.url
            serviceReady = false

            if currentURL.isEmpty {
                serviceStarter.reset()
            } else {
                tryStartService()
                persistAsLastUsedIfNeeded()
            }

            WindowSessionRegistry.shared.upsert(newValue)
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
        serviceStarter.start(command: cmd, healthURL: currentURL, stopCommand: stopCommand)
    }

    private func performRefresh() {
        if hasStartCommand, let cmd = startCommand {
            serviceReady = false
            serviceStarter.reset(runStopCommand: shouldStopOnClose)
            serviceStarter.start(command: cmd, healthURL: currentURL, stopCommand: stopCommand)
        } else {
            reloadToken = UUID()
        }
    }

    private func handleWindowClose() {
        guard shouldStopOnClose else { return }
        serviceStarter.stopCurrentService()
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
        if !windowConfig.name.isEmpty {
            return windowConfig.name
        }
        if let u = URL(string: currentURL), let host = u.host {
            return host + (u.path == "/" ? "" : u.path)
        }
        return currentURL.isEmpty ? "Windowed" : currentURL
    }

    private func openNewWindow(with config: WindowConfig) {
        openWindow(id: WindowedScene.browser, value: config)
        showURLSheet = false
        settingsHasChanges = false
    }

    private func persistAsLastUsedIfNeeded() {
        guard windowConfig.isConfigured else { return }
        WindowConfigStore.saveLastUsed(windowConfig)
    }

    private func applyInitialWindowSizeIfNeeded() {
        guard !hasAppliedInitialWindowSize,
              let window = hostWindow else {
            return
        }

        hasAppliedInitialWindowSize = true

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return }

        let widthRatio: CGFloat = currentURL.isEmpty ? 0.7 : 0.72
        let heightRatio: CGFloat = currentURL.isEmpty ? 0.8 : 0.82
        let minimumWidth: CGFloat = currentURL.isEmpty ? 800 : 1000
        let minimumHeight: CGFloat = currentURL.isEmpty ? 800 : 700

        let targetContentWidth = min(max(minimumWidth, visibleFrame.width * widthRatio), visibleFrame.width)
        let targetContentHeight = min(max(minimumHeight, visibleFrame.height * heightRatio), visibleFrame.height)
        let targetContentRect = NSRect(x: 0, y: 0, width: targetContentWidth, height: targetContentHeight)
        let rawTargetFrame = window.frameRect(forContentRect: targetContentRect)
        let targetFrame = NSRect(
            x: 0,
            y: 0,
            width: min(rawTargetFrame.width, visibleFrame.width),
            height: min(rawTargetFrame.height, visibleFrame.height)
        )
        let centeredOrigin = NSPoint(
            x: visibleFrame.midX - targetFrame.width / 2,
            y: visibleFrame.midY - targetFrame.height / 2
        )

        window.setFrame(NSRect(origin: centeredOrigin, size: targetFrame.size), display: true, animate: false)
    }

    private func ensureSettingsSheetFits() {
        guard let window = hostWindow else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return }

        let minimumContentSize = NSSize(width: 800, height: 820)
        let currentContentRect = window.contentLayoutRect
        let targetContentRect = NSRect(
            x: 0,
            y: 0,
            width: min(max(currentContentRect.width, minimumContentSize.width), visibleFrame.width),
            height: min(max(currentContentRect.height, minimumContentSize.height), visibleFrame.height)
        )
        let targetFrame = window.frameRect(forContentRect: targetContentRect)

        guard window.frame.height < targetFrame.height || window.frame.width < targetFrame.width else {
            return
        }

        let adjustedOrigin = NSPoint(
            x: min(max(window.frame.minX, visibleFrame.minX), visibleFrame.maxX - targetFrame.width),
            y: min(max(window.frame.maxY - targetFrame.height, visibleFrame.minY), visibleFrame.maxY - targetFrame.height)
        )

        window.setFrame(NSRect(origin: adjustedOrigin, size: targetFrame.size), display: true, animate: true)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.window = nsView.window
        }
    }
}
