import SwiftUI
import AppKit

struct URLInputSheet: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var isPresented: Bool
    @State private var inputURL: String = ""
    @State private var inputName: String = ""
    @State private var inputStartCommand: String = ""
    @State private var iconPath: String = ""
    @State private var presetsVersion: Int = 0
    @State private var pendingDelete: URLEntry? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            iconSection
                .padding(.top, 28)
                .padding(.bottom, 24)

            // Fields
            Form {
                Section {
                    TextField("Name", text: $inputName, prompt: Text("e.g. Hermes WebUI"))
                    TextField("URL", text: $inputURL, prompt: Text("http://127.0.0.1:8787"))
                        .font(.system(.callout, design: .monospaced))
                        .onSubmit { saveAndClose() }
                }

                Section {
                    HStack(alignment: .top) {
                        ZStack(alignment: .topLeading) {
                            if inputStartCommand.isEmpty {
                                Text("~/hermes-webui/ctl.sh start")
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                                    .padding(.top, 4)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $inputStartCommand)
                                .font(.system(.callout, design: .monospaced))
                                .frame(minHeight: 44, maxHeight: 88)
                                .scrollContentBackground(.hidden)
                        }
                        Button("Browse…") { pickScript() }
                            .controlSize(.small)
                    }
                } header: {
                    Text("Auto-start")
                } footer: {
                    Text("Type a command directly or browse to select a script. Add the appropriate argument for your script (e.g. start, run, up, serve). If none needed, just the path.")
                }

                let presets = loadPresets()
                let _ = presetsVersion  // force re-render on delete
                if !presets.isEmpty {
                    Section("History") {
                        ForEach(presets, id: \.url) { entry in
                            Button {
                                inputURL = entry.url
                                inputName = entry.name
                                inputStartCommand = entry.startCommand ?? ""
                                saveAndClose()
                            } label: {
                                presetRow(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(width: 550, height: presetsHeight)
            .alert("Delete this entry?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    if let entry = pendingDelete {
                        deletePreset(url: entry.url)
                        pendingDelete = nil
                    }
                }
                if let entry = pendingDelete {
                    Text(entry.name.isEmpty ? entry.url : entry.name)
                }
            }

            // Buttons
            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Open") { saveAndClose() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(inputURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 550)
        .onAppear {
            inputURL = savedURL
            inputName = savedName
            iconPath = UserDefaults.standard.string(forKey: "customIconPath") ?? ""
            // Load start command from current preset.
            if let entry = loadPresets().first(where: { $0.url == savedURL }) {
                inputStartCommand = entry.startCommand ?? ""
            }
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(spacing: 6) {
            if let icon = loadIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(.quaternary)
            }

            HStack(spacing: 10) {
                Button(iconPath.isEmpty ? "Choose Icon…" : "Change…") { pickIcon() }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !iconPath.isEmpty {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Button("Remove") {
                        iconPath = ""
                        UserDefaults.standard.removeObject(forKey: "customIconPath")
                        setAppIcon(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.red.opacity(0.8))
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Preset Row

    private func presetRow(_ entry: URLEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name.isEmpty ? entry.url : entry.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !entry.name.isEmpty {
                    Text(entry.url)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let cmd = entry.startCommand, !cmd.isEmpty {
                    Text(cmd)
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button {
                pendingDelete = entry
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private var presetsHeight: CGFloat {
        let count = loadPresets().count
        if count == 0 { return 260 }
        return CGFloat(280 + min(count, 5) * 56)
    }

    private func saveAndClose() {
        let url = inputURL.trimmingCharacters(in: .whitespaces)
        let name = inputName.trimmingCharacters(in: .whitespaces)
        let cmd = inputStartCommand.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        savedURL = url
        savedName = name
        savePreset(url: url, name: name, startCommand: cmd)
        isPresented = false
    }

    private func loadPresets() -> [URLEntry] {
        guard let data = UserDefaults.standard.data(forKey: "urlPresets"),
              let list = try? JSONDecoder().decode([URLEntry].self, from: data) else {
            return []
        }
        return list
    }

    private func deletePreset(url: String) {
        let list = loadPresets().filter { $0.url != url }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "urlPresets")
        }
        presetsVersion += 1
    }

    private func savePreset(url: String, name: String, startCommand: String?) {
        var list = loadPresets().filter { $0.url != url }
        list.insert(URLEntry(url: url, name: name, startCommand: startCommand), at: 0)
        if list.count > 5 { list = Array(list.prefix(5)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "urlPresets")
        }
    }

    // MARK: - Browse Script

    private func pickScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.unixExecutable, .shellScript, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a startup script"

        if panel.runModal() == .OK, let url = panel.url {
            inputStartCommand = url.path
        }
    }

    // MARK: - Icon

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
    var startCommand: String?
}
