import SwiftUI
import AppKit

struct URLInputSheet: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var isPresented: Bool
    @State private var inputURL: String = ""
    @State private var inputName: String = ""
    @State private var iconPath: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Icon preview
            VStack(spacing: 8) {
                if let icon = loadIcon() {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                }

                Button(action: pickIcon) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text(iconPath.isEmpty ? "Set App Icon" : "Change Icon")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                if !iconPath.isEmpty {
                    Button(action: {
                        iconPath = ""
                        UserDefaults.standard.removeObject(forKey: "customIconPath")
                        setAppIcon(nil)
                    }) {
                        Text("Remove Icon")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. Hermes WebUI", text: $inputName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("http://127.0.0.1:8787", text: $inputURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { saveAndClose() }
                }

                let presets = loadPresets()
                if !presets.isEmpty {
                    Divider()
                    Text("History:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(presets, id: \.url) { entry in
                        Button(action: {
                            inputURL = entry.url
                            inputName = entry.name
                            saveAndClose()
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(entry.name.isEmpty ? entry.url : entry.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(entry.url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .frame(width: 400)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Go") {
                    saveAndClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(inputURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(30)
        .onAppear {
            inputURL = savedURL
            inputName = savedName
            iconPath = UserDefaults.standard.string(forKey: "customIconPath") ?? ""
        }
    }

    private func saveAndClose() {
        let url = inputURL.trimmingCharacters(in: .whitespaces)
        let name = inputName.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        savedURL = url
        savedName = name
        savePreset(url: url, name: name)
        isPresented = false
    }

    private func loadPresets() -> [URLEntry] {
        guard let data = UserDefaults.standard.data(forKey: "urlPresets"),
              let list = try? JSONDecoder().decode([URLEntry].self, from: data) else {
            return []
        }
        return list
    }

    private func savePreset(url: String, name: String) {
        var list = loadPresets().filter { $0.url != url }
        list.insert(URLEntry(url: url, name: name), at: 0)
        if list.count > 5 { list = Array(list.prefix(5)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "urlPresets")
        }
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .icns, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image for the app icon"

        if panel.runModal() == .OK, let url = panel.url {
            // Copy to app support
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("WebShell")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("icon\(url.pathExtension)")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)

            iconPath = dest.path
            UserDefaults.standard.set(dest.path, forKey: "customIconPath")
            setAppIcon(NSImage(contentsOf: dest))
        }
    }

    private func loadIcon() -> NSImage? {
        let path = iconPath.isEmpty ? (UserDefaults.standard.string(forKey: "customIconPath") ?? "") : iconPath
        guard !path.isEmpty, let img = NSImage(contentsOfFile: path) else { return nil }
        return img
    }

    private func setAppIcon(_ image: NSImage?) {
        NSApplication.shared.applicationIconImage = image
    }
}

struct URLEntry: Codable, Hashable {
    let url: String
    let name: String
}
