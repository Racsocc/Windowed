import SwiftUI
import AppKit

struct URLInputSheet: View {
    @Binding var savedURL: String
    @Binding var savedName: String
    @Binding var isPresented: Bool
    @Binding var hasChanges: Bool
    @State private var inputURL: String = ""
    @State private var inputName: String = ""
    @State private var inputStartCommand: String = ""
    @State private var inputStopCommand: String = ""
    @State private var stopServiceOnClose: Bool = false
    @State private var iconPath: String = ""
    @State private var presetsVersion: Int = 0
    @State private var pendingDelete: URLEntry? = nil
    @State private var showDiscardAlert: Bool = false
    @State private var urlValidationMessage: String? = nil

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
                    if let urlValidationMessage {
                        Text(urlValidationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
                    Toggle("Stop service when window closes", isOn: $stopServiceOnClose)
                    if stopServiceOnClose {
                        HStack(alignment: .top) {
                            ZStack(alignment: .topLeading) {
                                if inputStopCommand.isEmpty {
                                    Text("~/hermes-webui/ctl.sh stop")
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(.quaternary)
                                        .padding(.top, 4)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: $inputStopCommand)
                                    .font(.system(.callout, design: .monospaced))
                                    .frame(minHeight: 44, maxHeight: 88)
                                    .scrollContentBackground(.hidden)
                            }
                            Button("Browse…") { pickStopScript() }
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Auto-start")
                } footer: {
                    Text("Type a command directly or browse to select a script. Add the appropriate argument for your script (e.g. start, run, up, serve). If you enable stop-on-close, provide a matching stop command such as stop or down.")
                }

                let presets = loadPresets()
                let _ = presetsVersion  // force re-render on delete
                if !presets.isEmpty {
                    Section("History") {
                        ForEach(presets, id: \.url) { entry in
                            presetRow(entry)
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
                Button("Cancel") {
                    isPresented = false
                }
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
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            // Start blank — ready to add a new entry.
            inputURL = ""
            inputName = ""
            inputStartCommand = ""
            inputStopCommand = ""
            stopServiceOnClose = false
            iconPath = ""
            hasChanges = false
            urlValidationMessage = nil
        }
        .onChange(of: inputURL) { _, _ in
            urlValidationMessage = nil
            updateHasChanges()
        }
        .onChange(of: inputName) { _, _ in updateHasChanges() }
        .onChange(of: inputStartCommand) { _, _ in updateHasChanges() }
        .onChange(of: inputStopCommand) { _, _ in updateHasChanges() }
        .onChange(of: stopServiceOnClose) { _, _ in updateHasChanges() }
        .onChange(of: iconPath) { _, _ in updateHasChanges() }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(spacing: 6) {
            Group {
                if let icon = loadIcon() {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "arrow.down.app.dashed")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { pickIcon() }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(iconPath.isEmpty ? Color.gray.opacity(0.2) : Color.clear)
            )

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
            HStack(spacing: 10) {
                if let path = entry.iconPath, !path.isEmpty, let img = NSImage(contentsOfFile: path) {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                        .frame(width: 16)
                }

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
                    if entry.shouldStopOnClose,
                       let stopCommand = entry.stopCommand, !stopCommand.isEmpty {
                        Text("Stop: \(stopCommand)")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openPreset(entry)
            }

            Button {
                togglePin(entry)
            } label: {
                Image(systemName: "arrow.up.to.line.compact")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(entry.isPinned ? Color.blue : Color.gray.opacity(0.4))
                    .padding(.top, 1)
                    .padding(.bottom, 3)
            }
            .buttonStyle(.plain)
            .offset(x: -21, y: 2)

            Button {
                // Load preset into fields for editing.
                inputURL = entry.url
                inputName = entry.name
                inputStartCommand = entry.startCommand ?? ""
                inputStopCommand = entry.stopCommand ?? ""
                stopServiceOnClose = entry.shouldStopOnClose
                iconPath = entry.iconPath ?? ""
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .offset(x: -16, y: 0)

            Button {
                pendingDelete = entry
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .offset(x: -10)
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
        let stopCmd = inputStopCommand.trimmingCharacters(in: .whitespaces)
        let icon = iconPath.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        guard validateURL(url) != nil else {
            urlValidationMessage = "请输入有效的 http:// 或 https:// URL"
            return
        }
        guard !stopServiceOnClose || !stopCmd.isEmpty else {
            urlValidationMessage = "开启自动停止时，请填写 Stop command"
            return
        }

        urlValidationMessage = nil
        savedURL = url
        savedName = name
        savePreset(
            url: url,
            name: name,
            startCommand: cmd,
            stopCommand: stopCmd,
            stopOnClose: stopServiceOnClose,
            iconPath: icon
        )
        // Apply the preset's icon to the app.
        if !icon.isEmpty, let img = NSImage(contentsOfFile: icon) {
            NSApplication.shared.applicationIconImage = img
        } else {
            NSApplication.shared.applicationIconImage = nil
        }
        hasChanges = false
        isPresented = false
    }

    private func updateHasChanges() {
        hasChanges = !inputURL.trimmingCharacters(in: .whitespaces).isEmpty
            || !inputName.trimmingCharacters(in: .whitespaces).isEmpty
            || !inputStartCommand.trimmingCharacters(in: .whitespaces).isEmpty
            || !inputStopCommand.trimmingCharacters(in: .whitespaces).isEmpty
            || stopServiceOnClose
            || !iconPath.isEmpty
    }

    private func loadPresets() -> [URLEntry] {
        guard let data = UserDefaults.standard.data(forKey: "urlPresets"),
              let list = try? JSONDecoder().decode([URLEntry].self, from: data) else {
            return []
        }
        return orderedPresets(from: list)
    }

    private func deletePreset(url: String) {
        let list = loadPresets().filter { $0.url != url }
        savePresetsList(list)
        presetsVersion += 1
    }

    private func togglePin(_ entry: URLEntry) {
        var list = loadPresets().filter { $0.url != entry.url }
        var updated = entry
        updated.pinned = !entry.isPinned
        let insertionIndex = updated.isPinned ? 0 : list.prefix { $0.isPinned }.count
        list.insert(updated, at: insertionIndex)
        savePresetsList(list)
        presetsVersion += 1
    }

    private func savePresetsList(_ list: [URLEntry]) {
        let normalized = limitedPresets(list)
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: "urlPresets")
        }
    }

    private func savePreset(
        url: String,
        name: String,
        startCommand: String?,
        stopCommand: String?,
        stopOnClose: Bool,
        iconPath: String? = nil
    ) {
        let existing = loadPresets().first(where: { $0.url == url })
        var list = loadPresets().filter { $0.url != url }
        var entry = URLEntry(
            url: url,
            name: name,
            startCommand: startCommand,
            stopCommand: stopCommand,
            stopOnClose: stopOnClose,
            iconPath: iconPath
        )
        entry.pinned = existing?.isPinned ?? false
        let insertionIndex = entry.isPinned ? 0 : list.prefix { $0.isPinned }.count
        list.insert(entry, at: insertionIndex)
        savePresetsList(list)
    }

    private func openPreset(_ entry: URLEntry) {
        inputURL = entry.url
        inputName = entry.name
        inputStartCommand = entry.startCommand ?? ""
        inputStopCommand = entry.stopCommand ?? ""
        stopServiceOnClose = entry.shouldStopOnClose
        iconPath = entry.iconPath ?? ""
        saveAndClose()
    }

    private func validateURL(_ rawURL: String) -> URL? {
        guard let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func orderedPresets(from list: [URLEntry]) -> [URLEntry] {
        let pinned = list.filter { $0.isPinned }
        let unpinned = list.filter { !$0.isPinned }
        return pinned + unpinned
    }

    private func limitedPresets(_ list: [URLEntry]) -> [URLEntry] {
        var normalized = orderedPresets(from: list)
        while normalized.count > 10 {
            if let index = normalized.lastIndex(where: { !$0.isPinned }) {
                normalized.remove(at: index)
            } else {
                normalized.removeLast()
            }
        }
        return normalized
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

    private func pickStopScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.unixExecutable, .shellScript, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a stop script"

        if panel.runModal() == .OK, let url = panel.url {
            inputStopCommand = url.path
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
            applyIcon(url.path)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            let ext = url.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "icns", "tiff"].contains(ext) else { return }
            DispatchQueue.main.async {
                applyIcon(url.path)
            }
        }
        return true
    }

    private func applyIcon(_ path: String) {
        iconPath = path
        if let img = NSImage(contentsOfFile: path) {
            setAppIcon(img)
        }
    }

    private func loadIcon() -> NSImage? {
        guard !iconPath.isEmpty, let img = NSImage(contentsOfFile: iconPath) else { return nil }
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
    var stopCommand: String?
    var stopOnClose: Bool?
    var iconPath: String?
    var pinned: Bool?

    var isPinned: Bool { pinned == true }
    var shouldStopOnClose: Bool { stopOnClose == true }
}
