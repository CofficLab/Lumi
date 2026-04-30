import SwiftUI
import MagicKit
import CodeEditTextView

/// 编辑器工具栏视图
/// 包含字体大小、缩进、主题切换等设置
struct EditorToolbarView: View {
    
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var state: EditorState
    let canSplitEditor: Bool
    let onSplitHorizontal: () -> Void
    let onSplitVertical: () -> Void
    let onUnsplit: () -> Void

    init(
        state: EditorState,
        canSplitEditor: Bool = false,
        onSplitHorizontal: @escaping () -> Void = {},
        onSplitVertical: @escaping () -> Void = {},
        onUnsplit: @escaping () -> Void = {}
    ) {
        self._state = ObservedObject(wrappedValue: state)
        self.canSplitEditor = canSplitEditor
        self.onSplitHorizontal = onSplitHorizontal
        self.onSplitVertical = onSplitVertical
        self.onUnsplit = onUnsplit
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 左侧：固定工具（字体大小 + 缩进）
            fontSizer
            
            Divider()
                .frame(height: 14)
            
            indentSettings
            
            Divider()
                .frame(height: 14)

            saveBehaviorSettings

            Divider()
                .frame(height: 14)
            
            // 中间：切换开关（可压缩）
            toggleButtons

            Divider()
                .frame(height: 14)

            splitEditorControls

            commandPaletteControl

            ForEach(centerToolbarItems) { item in
                item.content(state)
            }

            if isFindPanelVisible {
                Divider()
                    .frame(height: 14)

                findReplaceControls
            }

            if state.hasExternalFileConflict {
                Divider()
                    .frame(height: 14)

                externalFileConflictControl
            }

            if shouldShowLargeFileIndicator {
                Divider()
                    .frame(height: 14)

                largeFileIndicator
            }

            Spacer(minLength: 0)

            ForEach(trailingToolbarItems) { item in
                item.content(state)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
        .background(findKeyboardShortcutHost)
    }

    private var centerToolbarItems: [EditorToolbarItemSuggestion] {
        state.editorToolbarItems().filter { $0.placement == .center }
    }

    private var trailingToolbarItems: [EditorToolbarItemSuggestion] {
        state.editorToolbarItems().filter { $0.placement == .trailing }
    }

    private var isFindPanelVisible: Bool {
        state.editorState.findPanelVisible ?? false
    }

    private var findTextBinding: Binding<String> {
        Binding(
            get: { state.editorState.findText ?? "" },
            set: { state.updateFindQuery($0) }
        )
    }

    private var replaceTextBinding: Binding<String> {
        Binding(
            get: { state.editorState.replaceText ?? "" },
            set: { state.updateReplaceQuery($0) }
        )
    }

    private var selectedMatchDescription: String {
        let currentIndex = (state.activeSession.findReplaceState.selectedMatchIndex ?? -1) + 1
        let total = state.findMatches.count
        guard total > 0, currentIndex > 0 else { return "0/0" }
        return "\(currentIndex)/\(total)"
    }

    private var replacePreviewSummary: String? {
        guard let current = state.currentFindMatch,
              let replacement = state.currentReplacePreviewText else { return nil }
        let matched = current.matchedText.count > 14 ? String(current.matchedText.prefix(14)) + "..." : current.matchedText
        let target = replacement.count > 14 ? String(replacement.prefix(14)) + "..." : replacement
        return "\(matched) -> \(target)"
    }

    private var shouldShowLargeFileIndicator: Bool {
        state.largeFileMode != .normal || state.longestDetectedLine != nil
    }

    private var largeFileModeTitle: String {
        switch state.largeFileMode {
        case .normal:
            return "Normal File"
        case .medium:
            return "Medium File"
        case .large:
            return "Large File"
        case .mega:
            return "Mega File"
        }
    }

    private var largeFileModeSummary: String {
        var items: [String] = []
        if state.largeFileMode.isSemanticTokensDisabled {
            items.append("semantic")
        }
        if state.isLongLineProtectionSuppressingSyntaxHighlighting {
            items.append("long-line syntax")
        }
        if state.largeFileMode.isInlayHintsDisabled {
            items.append("inlay")
        }
        if state.largeFileMode.isFoldingDisabled {
            items.append("folding")
        }
        if state.largeFileMode.isMinimapDisabled {
            items.append("minimap")
        }
        if state.isTruncated {
            items.append("truncated")
        }
        if state.longestDetectedLine != nil {
            items.append("long line")
        }
        if items.isEmpty {
            return largeFileModeTitle
        }
        return "\(largeFileModeTitle) · \(items.joined(separator: ", "))"
    }

    private var viewportRenderSummary: String? {
        guard !state.viewportVisibleLineRange.isEmpty else { return nil }

        let visibleStart = state.viewportVisibleLineRange.lowerBound + 1
        let visibleEnd = state.viewportVisibleLineRange.upperBound
        let renderStart = state.viewportRenderLineRange.lowerBound + 1
        let renderEnd = state.viewportRenderLineRange.upperBound
        return "Visible L\(visibleStart)-\(visibleEnd) · Render L\(renderStart)-\(renderEnd)"
    }
    
    // MARK: - Font Sizer
    
    private var fontSizer: some View {
        HStack(spacing: 2) {
            Text(String(localized: "A", table: "LumiEditor"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            
            Button {
                state.fontSize = max(10, state.fontSize - 1)
                state.persistConfig()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
            
            Text("\(Int(state.fontSize))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .frame(width: 24)
            
            Button {
                state.fontSize = min(28, state.fontSize + 1)
                state.persistConfig()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
        }
    }
    
    // MARK: - Indent Settings
    
    private var indentSettings: some View {
        Menu {
            Button("Tab (↹)") {
                state.useSpaces = false
                state.persistConfig()
            }
            
            Button("2 Spaces") {
                state.useSpaces = true
                state.tabWidth = 2
                state.persistConfig()
            }
            
            Button("4 Spaces") {
                state.useSpaces = true
                state.tabWidth = 4
                state.persistConfig()
            }
            
            Button("8 Spaces") {
                state.useSpaces = true
                state.tabWidth = 8
                state.persistConfig()
            }
        } label: {
            Image(systemName: "increase.indent")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 22, height: 20)
        .fixedSize()
    }

    private var saveBehaviorSettings: some View {
        Menu {
            Toggle(isOn: Binding(
                get: { state.formatOnSave },
                set: { newValue in
                    state.formatOnSave = newValue
                    state.persistConfig()
                }
            )) {
                Text("Format on Save")
            }

            Toggle(isOn: Binding(
                get: { state.organizeImportsOnSave },
                set: { newValue in
                    state.organizeImportsOnSave = newValue
                    state.persistConfig()
                }
            )) {
                Text("Organize Imports on Save")
            }

            Toggle(isOn: Binding(
                get: { state.fixAllOnSave },
                set: { newValue in
                    state.fixAllOnSave = newValue
                    state.persistConfig()
                }
            )) {
                Text("Fix All on Save")
            }

            Toggle(isOn: Binding(
                get: { state.trimTrailingWhitespaceOnSave },
                set: { newValue in
                    state.trimTrailingWhitespaceOnSave = newValue
                    state.persistConfig()
                }
            )) {
                Text("Trim Trailing Whitespace")
            }

            Toggle(isOn: Binding(
                get: { state.insertFinalNewlineOnSave },
                set: { newValue in
                    state.insertFinalNewlineOnSave = newValue
                    state.persistConfig()
                }
            )) {
                Text("Insert Final Newline")
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 22, height: 20)
        .fixedSize()
    }

    private var externalFileConflictControl: some View {
        Menu {
            Button(state.isEditingProjectPBXProj ? "Use Xcode Version" : "Reload from Disk") {
                state.reloadExternalFileConflict()
            }

            Button(state.isEditingProjectPBXProj ? "Use Lumi Version" : "Keep Editor Version") {
                state.keepEditorVersionForExternalConflict()
            }
        } label: {
            Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .frame(width: 22, height: 22)
        }
        .help(state.saveState.label)
        .menuStyle(.borderlessButton)
        .frame(width: 22, height: 20)
        .fixedSize()
    }

    private var largeFileIndicator: some View {
        Menu {
            Text(largeFileModeTitle)
            if state.largeFileMode.isSemanticTokensDisabled {
                Text("Semantic tokens disabled")
            }
            if state.largeFileMode.isInlayHintsDisabled {
                Text("Inlay hints disabled")
            }
            if state.largeFileMode.isFoldingDisabled {
                Text("Folding ribbon disabled")
            }
            if state.largeFileMode.isMinimapDisabled {
                Text("Minimap disabled")
            }
            if state.isTruncated {
                Text("Editing disabled for truncated preview")
                if state.canLoadFullFile {
                    Button("Load Full File") {
                        state.loadFullFileFromDisk()
                    }
                }
            }
            if let longestLine = state.longestDetectedLine {
                Text("Long line: L\(longestLine.line + 1) · \(longestLine.length) chars")
            }
            if let viewportRenderSummary {
                Divider()
                Text(viewportRenderSummary)
            }
            if state.largeFileMode.maxSyntaxHighlightLines != .max {
                Text("Syntax highlighting limit: first \(state.largeFileMode.maxSyntaxHighlightLines.formatted()) lines")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: state.largeFileMode == .normal ? "text.line.first.and.arrowtriangle.forward" : "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .medium))
                Text(largeFileModeSummary)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(state.largeFileMode == .normal ? AppUI.Color.semantic.textSecondary : .orange)
            .padding(.horizontal, 6)
            .frame(height: 22)
            .background(AppUI.Color.semantic.textTertiary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .help(largeFileModeSummary)
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    // MARK: - Toggle Buttons
    
    private var toggleButtons: some View {
        HStack(spacing: 4) {
            // 自动换行
            ToolbarToggle(
                icon: "text.justify.leading",
                isActive: state.wrapLines
            ) {
                state.wrapLines.toggle()
                state.persistConfig()
            }
            
            // 行号
            ToolbarToggle(
                icon: "list.number",
                isActive: state.showGutter
            ) {
                state.showGutter.toggle()
                state.persistConfig()
            }
            
            // Minimap
            ToolbarToggle(
                icon: "rectangle.split.1x2",
                isActive: state.minimapPolicy.isVisible,
                isEnabled: !state.minimapPolicy.isForcedHidden
            ) {
                state.showMinimap.toggle()
                state.persistConfig()
            }
            .help(state.minimapPolicy.detailText)
            
            // 多光标
            ToolbarToggle(
                icon: "cursorarrow.rays",
                isActive: state.multiCursorState.isEnabled
            ) {
                if state.multiCursorState.isEnabled {
                    state.performEditorCommand(id: "builtin.clear-additional-cursors")
                } else {
                    state.performEditorCommand(id: "builtin.add-next-occurrence")
                }
                syncSelectionsToFocusedTextView()
            }
            .help(state.multiCursorState.isEnabled
                ? String(localized: "Clear Additional Cursors", table: "LumiEditor")
                : String(localized: "Add Next Occurrence", table: "LumiEditor"))
        }
    }

    private var splitEditorControls: some View {
        HStack(spacing: 4) {
            ToolbarToggle(
                icon: "rectangle.split.2x1",
                isActive: false
            ) {
                onSplitHorizontal()
            }
            .help(String(localized: "Split Editor Right", table: "LumiEditor"))
            .disabled(!canSplitEditor)

            ToolbarToggle(
                icon: "rectangle.split.1x2",
                isActive: false
            ) {
                onSplitVertical()
            }
            .help(String(localized: "Split Editor Down", table: "LumiEditor"))
            .disabled(!canSplitEditor)

            ToolbarToggle(
                icon: "rectangle",
                isActive: false
            ) {
                onUnsplit()
            }
            .help(String(localized: "Close Split Editor", table: "LumiEditor"))
            .disabled(!canSplitEditor)
        }
    }

    private var commandPaletteControl: some View {
        ToolbarToggle(
            icon: "command",
            isActive: false
        ) {
            state.performEditorCommand(id: "builtin.command-palette")
        }
        .help(String(localized: "Command Palette", table: "LumiEditor") + " (\(EditorCommandBindings.commandPalette.kernelShortcut.displayText))")
    }

    private var findReplaceControls: some View {
        HStack(spacing: 6) {
            TextField(String(localized: "Find", table: "LumiEditor"), text: findTextBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            TextField(String(localized: "Replace", table: "LumiEditor"), text: replaceTextBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

            Text(selectedMatchDescription)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 36)

            if let replacePreviewSummary {
                Text(replacePreviewSummary)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppUI.Color.semantic.primary.opacity(0.1))
                    )
                    .lineLimit(1)
            }

            ToolbarToggle(icon: "arrow.up", isActive: false) {
                state.performEditorCommand(id: "builtin.find-previous")
            }
            .help(String(localized: "Find Previous", table: "LumiEditor"))

            ToolbarToggle(icon: "arrow.down", isActive: false) {
                state.performEditorCommand(id: "builtin.find-next")
            }
            .help(String(localized: "Find Next", table: "LumiEditor"))

            ToolbarToggle(icon: "arrow.triangle.2.circlepath", isActive: false) {
                state.performEditorCommand(id: "builtin.replace-current")
            }
            .help(String(localized: "Replace", table: "LumiEditor"))

            ToolbarToggle(icon: "square.stack.3d.up", isActive: false) {
                state.performEditorCommand(id: "builtin.replace-all")
            }
            .help(String(localized: "Replace All", table: "LumiEditor"))

            Menu {
                Toggle(isOn: Binding(
                    get: { state.activeSession.findReplaceState.options.isCaseSensitive },
                    set: { newValue in
                        state.updateFindReplaceOptions { $0.isCaseSensitive = newValue }
                    }
                )) {
                    Text("Case Sensitive")
                }

                Toggle(isOn: Binding(
                    get: { state.activeSession.findReplaceState.options.matchesWholeWord },
                    set: { newValue in
                        state.updateFindReplaceOptions { $0.matchesWholeWord = newValue }
                    }
                )) {
                    Text("Whole Word")
                }

                Toggle(isOn: Binding(
                    get: { state.activeSession.findReplaceState.options.isRegexEnabled },
                    set: { newValue in
                        state.updateFindReplaceOptions { $0.isRegexEnabled = newValue }
                    }
                )) {
                    Text("Use Regular Expression")
                }

                Toggle(isOn: Binding(
                    get: { state.activeSession.findReplaceState.options.inSelectionOnly },
                    set: { newValue in
                        state.updateFindReplaceOptions { $0.inSelectionOnly = newValue }
                    }
                )) {
                    Text("In Selection")
                }

                Toggle(isOn: Binding(
                    get: { state.activeSession.findReplaceState.options.preservesCase },
                    set: { newValue in
                        state.updateFindReplaceOptions { $0.preservesCase = newValue }
                    }
                )) {
                    Text("Preserve Case")
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22, height: 20)
            .fixedSize()

            ToolbarToggle(icon: "xmark", isActive: false) {
                state.closeFindPanel()
            }
            .help(String(localized: "Close", table: "Localizable"))
        }
    }

    @ViewBuilder
    private var findKeyboardShortcutHost: some View {
        if isFindPanelVisible {
            ZStack {
                Button(action: {
                    state.performEditorCommand(id: "builtin.find-next")
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.return, modifiers: [])

                Button(action: {
                    state.performEditorCommand(id: "builtin.find-previous")
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.return, modifiers: [.shift])

                Button(action: {
                    state.performEditorCommand(id: "builtin.replace-current")
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button(action: {
                    state.performEditorCommand(id: "builtin.replace-all")
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Button(action: {
                    state.closeFindPanel()
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0.001)
            .allowsHitTesting(false)
        }
    }
    
    private func syncSelectionsToFocusedTextView() {
        guard let responder = NSApp.keyWindow?.firstResponder else { return }
        guard let textView = responder as? TextView else { return }
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
    }
}

// MARK: - Toolbar Toggle Button

private struct ToolbarToggle: View {
    let icon: String
    let isActive: Bool
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(foregroundColor)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return AppUI.Color.semantic.textTertiary.opacity(0.45) }
        return isActive ? AppUI.Color.semantic.primary : AppUI.Color.semantic.textTertiary
    }

    private var backgroundColor: Color {
        guard isEnabled else { return AppUI.Color.semantic.textTertiary.opacity(0.04) }
        return isActive ? AppUI.Color.semantic.primary.opacity(0.1) : Color.clear
    }
}
