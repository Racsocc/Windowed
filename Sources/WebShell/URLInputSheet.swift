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
        VStack(spacing: 0) {
            // Icon area — subtle, centered
            iconSection
                .padding(.top, 24)
                .padding(.bottom, 20)

            // Form fields
            Form {
                Section {
                    TextField("Display Name", text: $inputName, prompt: Text("e.g. Hermes WebUI"))
                    TextField("URL", text: $inputURL, prompt: Text("http://127.0.0.1:8787"))
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { saveAndClose() }
                }

                let presets = loadPresets()
                if !presets.isEmpty {
                    Section("Recent") {
                        ForEach(presets, id: \.url) { entry in
                            Button {
                                inputURL = entry.url
                                inputName = entry.name
                                saveAndClose()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name.isEmpty ? entry.url : entry.name)
                                            .foregroundStyle(.primary)
                                        Text(entry.url)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.quaternary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(width: 420, height: presetsHeight)

            // Bottom buttons
            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open") { saveAndClose() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(inputURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 420)
        .onAppear {
            inputURL = savedURL
            inputName = savedName
            iconPath = UserDefaults.standard.string(forKey: "customIconPath") ?? ""
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        VStack(spacing: 8) {
            if let icon = loadIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button(iconPath.isEmpty ? "Set Icon…" : "Change…") { pickIcon() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !iconPath.isEmpty {
                    Button("Remove") {
                        iconPath = ""
                        UserDefaults.standard.removeObject(forKey: "customIconPath")
                        setAppIcon(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Helpers

    private var presetsHeight: CGFloat {
        let count = loadPresets().count
        if count == 0 { return 130 }
        return CGFloat(130 + min(count, 5) * 44)
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
