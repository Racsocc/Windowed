import Foundation

enum WindowConfigStore {
    private static let lastUsedKey = "windowed.lastUsedWindowConfig"
    private static let sessionKey = "windowed.windowSessionConfigs"

    static func loadLastUsed() -> WindowConfig? {
        guard let data = UserDefaults.standard.data(forKey: lastUsedKey),
              let config = try? JSONDecoder().decode(WindowConfig.self, from: data),
              config.isConfigured else {
            return nil
        }

        var restored = config
        restored.id = UUID()
        return restored
    }

    static func saveLastUsed(_ config: WindowConfig) {
        guard config.isConfigured,
              let data = try? JSONEncoder().encode(config) else {
            return
        }
        UserDefaults.standard.set(data, forKey: lastUsedKey)
    }

    static func loadWindowSession() -> [WindowConfig] {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let configs = try? JSONDecoder().decode([WindowConfig].self, from: data) else {
            return []
        }

        return configs
            .filter(\.isConfigured)
            .map { config in
                var restored = config
                restored.id = UUID()
                return restored
            }
    }

    static func saveWindowSession(_ configs: [WindowConfig]) {
        let normalized = configs.filter(\.isConfigured)
        guard let data = try? JSONEncoder().encode(normalized) else {
            return
        }
        UserDefaults.standard.set(data, forKey: sessionKey)
    }
}

final class WindowRestoreCoordinator {
    static let shared = WindowRestoreCoordinator()

    private let launchConfigs: [WindowConfig]
    private var didRestoreAdditionalWindows = false

    private init() {
        let sessionConfigs = WindowConfigStore.loadWindowSession()
        if !sessionConfigs.isEmpty {
            launchConfigs = sessionConfigs
        } else if let lastUsed = WindowConfigStore.loadLastUsed() {
            launchConfigs = [lastUsed]
        } else {
            launchConfigs = []
        }
    }

    var initialWindowConfig: WindowConfig {
        launchConfigs.first ?? WindowConfig()
    }

    func restoreAdditionalWindows(openWindow: (WindowConfig) -> Void) {
        guard !didRestoreAdditionalWindows else { return }
        didRestoreAdditionalWindows = true

        for config in launchConfigs.dropFirst() {
            openWindow(config)
        }
    }
}

final class WindowSessionRegistry {
    static let shared = WindowSessionRegistry()

    private let stateQueue = DispatchQueue(label: "Windowed.WindowSessionRegistry")
    private var configsByID: [UUID: WindowConfig] = [:]
    private var orderedIDs: [UUID] = []
    private var isTerminating = false

    func upsert(_ config: WindowConfig) {
        stateQueue.sync {
            if configsByID[config.id] == nil {
                orderedIDs.append(config.id)
            }
            configsByID[config.id] = config
            saveSnapshot()
        }
    }

    func remove(id: UUID) {
        stateQueue.sync {
            guard !isTerminating else { return }
            configsByID.removeValue(forKey: id)
            orderedIDs.removeAll { $0 == id }
            saveSnapshot()
        }
    }

    func beginTermination() {
        stateQueue.sync {
            isTerminating = true
            saveSnapshot()
        }
    }

    private func saveSnapshot() {
        let orderedConfigs = orderedIDs.compactMap { configsByID[$0] }
        WindowConfigStore.saveWindowSession(orderedConfigs)
    }
}

struct WindowConfig: Codable, Hashable, Identifiable {
    var id: UUID
    var url: String
    var name: String
    var iconPath: String?
    var startCommand: String?
    var stopCommand: String?
    var stopOnClose: Bool

    init(
        id: UUID = UUID(),
        url: String = "",
        name: String = "",
        iconPath: String? = nil,
        startCommand: String? = nil,
        stopCommand: String? = nil,
        stopOnClose: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.iconPath = iconPath
        self.startCommand = startCommand
        self.stopCommand = stopCommand
        self.stopOnClose = stopOnClose
    }

    var isConfigured: Bool {
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension URLEntry {
    func makeWindowConfig() -> WindowConfig {
        WindowConfig(
            url: url,
            name: name,
            iconPath: iconPath,
            startCommand: startCommand,
            stopCommand: stopCommand,
            stopOnClose: shouldStopOnClose
        )
    }
}
