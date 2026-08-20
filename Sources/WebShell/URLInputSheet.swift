import SwiftUI
import AppKit

struct URLInputSheet: View {
    @Binding var windowConfig: WindowConfig
    @Binding var isPresented: Bool
    @Binding var hasChanges: Bool
    let openInNewWindow: (WindowConfig) -> Void
    let containerSize: CGSize
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
    @State private var baselineConfig: WindowConfig = WindowConfig()
    @State private var editingPresetOriginalURL: String? = nil

    var body: some View {
        let presets = loadPresets()
        let _ = presetsVersion
        let layout = layoutMetrics()

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    iconSection
                        .padding(.top, 28)
                        .padding(.bottom, 24)

                    settingsForm
                        .padding(.horizontal, 20)

                    if !presets.isEmpty {
                        historySection(presets)
                            .padding(.top, 16)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: layout.scrollAreaHeight)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveAndClose() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(inputURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: layout.panelWidth, height: layout.panelHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
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
        .onAppear {
            beginCreateMode()
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

    private func layoutMetrics() -> PanelLayoutMetrics {
        let panelWidth = min(550, max(460, containerSize.width - 48))
        let maxPanelHeight = max(320, containerSize.height - 32)
        let targetPanelHeight = containerSize.height * 0.85
        let panelHeight = min(maxPanelHeight, max(360, targetPanelHeight))
        let buttonSectionHeight: CGFloat = 72
        let scrollAreaHeight = max(220, panelHeight - buttonSectionHeight)

        return PanelLayoutMetrics(
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            scrollAreaHeight: scrollAreaHeight
        )
    }

    private var settingsForm: some View {
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
                HStack(alignment: .center) {
                    commandField(
                        text: $inputStartCommand,
                        placeholder: "~/hermes-webui/ctl.sh start"
                    )
                    Button("Browse…") { pickScript() }
                        .controlSize(.small)
                }
                Toggle("Stop service when window closes", isOn: $stopServiceOnClose)
                if stopServiceOnClose {
                    HStack(alignment: .center) {
                        commandField(
                            text: $inputStopCommand,
                            placeholder: "~/hermes-webui/ctl.sh stop"
                        )
                        Button("Browse…") { pickStopScript() }
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("Auto-start")
            } footer: {
                Text("Type a command directly or browse to select a script. Add the appropriate argument for your script (e.g. start, run, up, serve). If you enable stop-on-close, provide a matching stop command such as stop or down.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
    }

    private func commandField(text: Binding<String>, placeholder: String) -> some View {
        AppKitCommandField(text: text, placeholder: placeholder)
            .frame(minHeight: 36)
    }

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
                openPreset(entry, forceNewWindow: true)
            } label: {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in new window")
            .offset(x: -24, y: 0)

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
                beginEditMode(with: entry)
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

    private func historySection(_ presets: [URLEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(presets, id: \.url) { entry in
                        presetRow(entry)
                            .padding(.vertical, 4)

                        if entry.url != presets.last?.url {
                            Divider()
                                .opacity(0.35)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func saveAndClose() {
        let draft = makeDraftConfig()
        guard draft.isConfigured else { return }
        guard validateURL(draft.url) != nil else {
            urlValidationMessage = "请输入有效的 http:// 或 https:// URL"
            return
        }
        guard !draft.stopOnClose || draft.stopCommand != nil else {
            urlValidationMessage = "开启自动停止时，请填写 Stop command"
            return
        }

        urlValidationMessage = nil
        apply(config: draft)
        savePreset(
            config: draft,
            replacingURL: editingPresetOriginalURL
        )
        baselineConfig = draft
        editingPresetOriginalURL = draft.url
        hasChanges = false
        isPresented = false
    }

    private func updateHasChanges() {
        let draft = makeDraftConfig()
        hasChanges = draft.url != baselineConfig.url
            || draft.name != baselineConfig.name
            || normalized(draft.startCommand ?? "") != normalized(baselineConfig.startCommand ?? "")
            || normalized(draft.stopCommand ?? "") != normalized(baselineConfig.stopCommand ?? "")
            || draft.stopOnClose != baselineConfig.stopOnClose
            || normalized(draft.iconPath ?? "") != normalized(baselineConfig.iconPath ?? "")
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
        if editingPresetOriginalURL == url {
            beginCreateMode()
        }
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

    private func savePreset(config: WindowConfig, replacingURL: String? = nil) {
        let existing = loadPresets().first { entry in
            entry.url == config.url || entry.url == replacingURL
        }
        var list = loadPresets().filter { entry in
            entry.url != config.url && entry.url != replacingURL
        }
        var entry = URLEntry(
            url: config.url,
            name: config.name,
            startCommand: config.startCommand,
            stopCommand: config.stopCommand,
            stopOnClose: config.stopOnClose,
            iconPath: config.iconPath
        )
        entry.pinned = existing?.isPinned ?? false
        let insertionIndex = entry.isPinned ? 0 : list.prefix { $0.isPinned }.count
        list.insert(entry, at: insertionIndex)
        savePresetsList(list)
    }

    private func openPreset(_ entry: URLEntry, forceNewWindow: Bool = false) {
        if shouldOpenPresetInCurrentWindow(forceNewWindow: forceNewWindow) {
            apply(config: entry.makeWindowConfig())
            hasChanges = false
            isPresented = false
        } else {
            openInNewWindow(entry.makeWindowConfig())
        }
    }

    private func shouldOpenPresetInCurrentWindow(forceNewWindow: Bool) -> Bool {
        if forceNewWindow {
            return false
        }

        if normalized(windowConfig.url).isEmpty {
            return true
        }

        let activeWindowCount = NSApp.windows.filter { window in
            window.isVisible && !window.isMiniaturized
        }.count

        return activeWindowCount <= 1
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
        let normalized = orderedPresets(from: list)
        let pinned = normalized.filter { $0.isPinned }
        let unpinned = normalized.filter { !$0.isPinned }
        return pinned + Array(unpinned.prefix(20))
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
    }

    private func loadIcon() -> NSImage? {
        guard !iconPath.isEmpty, let img = NSImage(contentsOfFile: iconPath) else { return nil }
        return img
    }

    private func beginCreateMode() {
        inputURL = ""
        inputName = ""
        inputStartCommand = ""
        inputStopCommand = ""
        stopServiceOnClose = false
        iconPath = ""
        baselineConfig = WindowConfig()
        editingPresetOriginalURL = nil
        hasChanges = false
        urlValidationMessage = nil
    }

    private func beginEditMode(with entry: URLEntry) {
        let config = entry.makeWindowConfig()
        inputURL = config.url
        inputName = config.name
        inputStartCommand = config.startCommand ?? ""
        inputStopCommand = config.stopCommand ?? ""
        stopServiceOnClose = config.stopOnClose
        iconPath = config.iconPath ?? ""
        baselineConfig = config
        editingPresetOriginalURL = entry.url
        hasChanges = false
        urlValidationMessage = nil
    }

    private func makeDraftConfig() -> WindowConfig {
        WindowConfig(
            id: windowConfig.id,
            url: normalized(inputURL),
            name: normalized(inputName),
            iconPath: normalized(iconPath).isEmpty ? nil : normalized(iconPath),
            startCommand: normalized(inputStartCommand).isEmpty ? nil : normalized(inputStartCommand),
            stopCommand: normalized(inputStopCommand).isEmpty ? nil : normalized(inputStopCommand),
            stopOnClose: stopServiceOnClose
        )
    }

    private func apply(config: WindowConfig) {
        windowConfig.url = config.url
        windowConfig.name = config.name
        windowConfig.startCommand = config.startCommand
        windowConfig.stopCommand = config.stopCommand
        windowConfig.stopOnClose = config.stopOnClose
        windowConfig.iconPath = config.iconPath
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AppKitCommandField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = PaddedCommandTextField()
        textField.delegate = context.coordinator
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.font = NSFont.monospacedSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize,
            weight: .regular
        )
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.cell?.lineBreakMode = .byClipping
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            if let editor = nsView.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: 0)
            }
        }

        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text = textField.stringValue
        }
    }
}

private final class PaddedCommandTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { PaddedCommandTextFieldCell.self }
        set { }
    }
}

private final class PaddedCommandTextFieldCell: NSTextFieldCell {
    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 4

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        adjustedRect(for: super.drawingRect(forBounds: rect))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(
            withFrame: adjustedRect(for: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            event: event
        )
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(
            withFrame: adjustedRect(for: rect),
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: selStart,
            length: selLength
        )
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        adjustedRect(for: super.titleRect(forBounds: rect))
    }

    private func adjustedRect(for rect: NSRect) -> NSRect {
        rect.insetBy(dx: horizontalPadding, dy: verticalPadding)
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

private struct PanelLayoutMetrics {
    let panelWidth: CGFloat
    let panelHeight: CGFloat
    let scrollAreaHeight: CGFloat
}
