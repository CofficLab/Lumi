import AppKit
import SwiftUI

struct KeyboardShortcutsSettingsView: View {
    @StateObject private var keybindingStore = EditorKeybindingStore.shared
    @State private var searchText = ""
    @State private var selectedCategory: EditorCommandCategory?
    @State private var recordingCommandID: String?
    @State private var validationMessage: String?

    private var filteredCommands: [EditorShortcutDefinition] {
        EditorShortcutCatalog.filteredCommands(query: searchText, category: selectedCategory)
    }

    private var groupedCommands: [(category: EditorCommandCategory, commands: [EditorShortcutDefinition])] {
        Dictionary(grouping: filteredCommands, by: \.category)
            .sorted { lhs, rhs in
                EditorCommandCategory.orderIndex(for: lhs.key.rawValue) < EditorCommandCategory.orderIndex(for: rhs.key.rawValue)
            }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(AppUI.Spacing.lg)
                .background(Color.clear)

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.lg) {
                    controlsCard

                    if let validationMessage {
                        warningCard(validationMessage)
                    }

                    if groupedCommands.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(groupedCommands, id: \.category) { section in
                            categoryCard(section.category, commands: section.commands)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, AppUI.Spacing.lg)
            }
        }
        .navigationTitle("快捷键")
    }

    private var headerCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "keyboard",
                    title: "快捷键",
                    subtitle: "搜索、录制和管理编辑器命令快捷键"
                )

                Spacer()

                if !keybindingStore.customBindings.isEmpty {
                    GlassButton(title: "恢复全部默认", style: .danger) {
                        keybindingStore.resetAll()
                        validationMessage = nil
                        recordingCommandID = nil
                    }
                    .frame(width: 160)
                }
            }
        }
    }

    private var controlsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: "command",
                    title: "命令搜索",
                    subtitle: "支持按命令名、分类、命令 ID 和快捷键搜索"
                )

                AppSearchBar(text: $searchText, placeholder: "搜索快捷键或命令…")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppUI.Spacing.sm) {
                        categoryChip(title: "全部", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(EditorCommandCategory.orderedCases.filter { $0 != .chat }, id: \.self) { category in
                            categoryChip(title: category.displayTitle, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                }

                Text(summaryText)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
    }

    private var emptyStateCard: some View {
        GlassCard {
            VStack(spacing: AppUI.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                Text("没有匹配的快捷键")
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Text("试试搜索命令名、命令 ID，或者像 `⌘⇧P` 这样的快捷键。")
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppUI.Spacing.xl)
        }
    }

    private func warningCard(_ message: String) -> some View {
        GlassCard {
            HStack(spacing: AppUI.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppUI.Color.semantic.warning)

                Text(message)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func categoryCard(_ category: EditorCommandCategory, commands: [EditorShortcutDefinition]) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                GlassSectionHeader(
                    icon: iconName(for: category),
                    title: category.displayTitle,
                    subtitle: "\(commands.count) 个命令"
                )

                GlassDivider()

                VStack(spacing: AppUI.Spacing.xs) {
                    ForEach(commands) { command in
                        shortcutRow(command)
                    }
                }
            }
        }
    }

    private func shortcutRow(_ command: EditorShortcutDefinition) -> some View {
        let effectiveShortcut = EditorShortcutCatalog.effectiveShortcut(for: command, customBindings: keybindingStore.customBindings)
        let isCustomized = keybindingStore.customBindings[command.id] != nil
        let isRecording = recordingCommandID == command.id

        return GlassRow {
            VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                HStack(alignment: .center, spacing: AppUI.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                        Text(command.title)
                            .font(AppUI.Typography.bodyEmphasized)
                            .foregroundColor(AppUI.Color.semantic.textPrimary)

                        Text(command.id)
                            .font(AppUI.Typography.caption1)
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AppUI.Spacing.xs) {
                        Text(effectiveShortcut?.displayText ?? "未设置")
                            .font(AppUI.Typography.bodyEmphasized)
                            .foregroundColor(AppUI.Color.semantic.textPrimary)

                        Text(isCustomized ? "自定义" : "默认")
                            .font(AppUI.Typography.caption2)
                            .foregroundColor(isCustomized ? AppUI.Color.semantic.primary : AppUI.Color.semantic.textTertiary)
                    }
                    .frame(width: 90, alignment: .trailing)

                    Button(isRecording ? "停止录制" : "录制快捷键") {
                        validationMessage = nil
                        recordingCommandID = isRecording ? nil : command.id
                    }
                    .buttonStyle(.bordered)

                    if isCustomized {
                        Button("恢复默认") {
                            keybindingStore.removeBinding(commandID: command.id)
                            validationMessage = nil
                            if recordingCommandID == command.id {
                                recordingCommandID = nil
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if isRecording {
                    VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                        ShortcutRecorderField(commandTitle: command.title) { shortcut in
                            applyRecordedShortcut(shortcut, for: command)
                        } onCancel: {
                            recordingCommandID = nil
                        }

                        Text(recorderHint(for: command))
                            .font(AppUI.Typography.caption2)
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }
                }
            }
        }
    }

    private func applyRecordedShortcut(_ shortcut: EditorCommandShortcut, for command: EditorShortcutDefinition) {
        guard !shortcut.modifiers.isEmpty else {
            validationMessage = "“\(command.title)” 的快捷键必须至少包含一个修饰键。"
            return
        }

        let conflicts = EditorShortcutCatalog.conflicts(
            for: command.id,
            candidate: shortcut,
            customBindings: keybindingStore.customBindings
        )

        guard conflicts.isEmpty else {
            let names = conflicts.map(\.title).joined(separator: "、")
            validationMessage = "“\(shortcut.displayText)” 已被 \(names) 使用。请先调整冲突命令，再保存这个绑定。"
            return
        }

        validationMessage = nil
        recordingCommandID = nil

        if shortcut == command.defaultShortcut {
            keybindingStore.removeBinding(commandID: command.id)
            return
        }

        keybindingStore.setBinding(
            commandID: command.id,
            key: shortcut.key,
            modifiers: shortcut.modifiers
        )
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppUI.Typography.caption1)
                .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
                .padding(.horizontal, AppUI.Spacing.md)
                .padding(.vertical, AppUI.Spacing.xs)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? AnyShapeStyle(AppUI.Color.semantic.primary.opacity(0.18))
                                : AnyShapeStyle(AppUI.Material.glass)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppUI.Color.semantic.primary.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        let customizedCount = keybindingStore.customBindings.count
        return "共 \(EditorShortcutCatalog.commands.count) 个命令，当前有 \(customizedCount) 个自定义绑定。"
    }

    private func recorderHint(for command: EditorShortcutDefinition) -> String {
        let defaultText = command.defaultShortcut?.displayText ?? "无默认快捷键"
        return "聚焦后直接按键录制。按 `Esc` 取消。默认：\(defaultText)"
    }

    private func iconName(for category: EditorCommandCategory) -> String {
        switch category {
        case .edit:
            return "pencil.line"
        case .find:
            return "magnifyingglass"
        case .navigation:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .workbench:
            return "square.split.2x1"
        case .multiCursor:
            return "cursorarrow.rays"
        case .format:
            return "text.justify"
        case .lsp:
            return "sparkles"
        case .save:
            return "square.and.arrow.down"
        case .chat:
            return "bubble.left.and.bubble.right"
        case .other:
            return "slider.horizontal.3"
        }
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    let commandTitle: String
    let onShortcut: (EditorCommandShortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.commandTitle = commandTitle
        view.onShortcut = onShortcut
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.commandTitle = commandTitle
        nsView.onShortcut = onShortcut
        nsView.onCancel = onCancel

        DispatchQueue.main.async {
            guard let window = nsView.window, window.firstResponder !== nsView else { return }
            window.makeFirstResponder(nsView)
        }
    }
}

private final class RecorderView: NSView {
    var commandTitle = ""
    var onShortcut: ((EditorCommandShortcut) -> Void)?
    var onCancel: (() -> Void)?

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = AppUI.Radius.sm
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.22).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor
            updateLabel()
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && event.modifierFlags.deviceIndependentModifiers.isEmpty {
            onCancel?()
            return
        }

        guard let shortcut = Self.shortcut(from: event) else {
            NSSound.beep()
            return
        }

        onShortcut?(shortcut)
    }

    private func updateLabel() {
        label.stringValue = "按下用于“\(commandTitle)”的新快捷键"
    }

    private static func shortcut(from event: NSEvent) -> EditorCommandShortcut? {
        let modifiers = event.modifierFlags.deviceIndependentModifiers.editorShortcutModifiers
        guard let key = normalizedKey(from: event) else { return nil }
        return EditorCommandShortcut(key: key, modifiers: modifiers)
    }

    private static func normalizedKey(from event: NSEvent) -> String? {
        switch event.keyCode {
        case 36:
            return "return"
        case 48:
            return "tab"
        case 49:
            return "space"
        case 51:
            return "delete"
        case 53:
            return "escape"
        case 123:
            return "left"
        case 124:
            return "right"
        case 125:
            return "down"
        case 126:
            return "up"
        default:
            guard let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let first = characters.first else {
                return nil
            }
            return String(first).lowercased()
        }
    }
}

private extension NSEvent.ModifierFlags {
    var deviceIndependentModifiers: NSEvent.ModifierFlags {
        intersection(.deviceIndependentFlagsMask)
    }

    var editorShortcutModifiers: [EditorCommandShortcut.Modifier] {
        var result: [EditorCommandShortcut.Modifier] = []
        if contains(.command) {
            result.append(.command)
        }
        if contains(.shift) {
            result.append(.shift)
        }
        if contains(.option) {
            result.append(.option)
        }
        if contains(.control) {
            result.append(.control)
        }
        return result
    }
}

#Preview("Keyboard Shortcuts") {
    KeyboardShortcutsSettingsView()
        .frame(width: 860, height: 720)
        .inRootView()
}
