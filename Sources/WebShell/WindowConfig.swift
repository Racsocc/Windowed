import Foundation

enum WindowConfigStore {
    private static let lastUsedKey = "windowed.lastUsedWindowConfig"

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
