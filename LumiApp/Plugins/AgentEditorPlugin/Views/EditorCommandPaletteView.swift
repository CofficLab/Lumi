import SwiftUI
import MagicKit

struct EditorCommandPaletteView: View {
    @ObservedObject var state: EditorState
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedCommandID: String?
    @State private var selectedCategory: EditorCommandCategory?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            GlassDivider()
            content
            GlassDivider()
            footer
        }
        .frame(minWidth: 560, idealWidth: 640, maxWidth: 760, minHeight: 420, idealHeight: 520)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            isSearchFocused = true
            selectFirstCommandIfNeeded()
        }
        .onChange(of: flattenedCommands.map(\.id)) { _, _ in
            normalizeSelection()
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Text(String(localized: "Command Palette", table: "LumiEditor"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textPrimary)

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            TextField(
                String(localized: "Search commands", table: "LumiEditor"),
                text: $query
            )
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .onSubmit {
                executeSelectedCommand()
            }

            categoryFilterStrip
        }
        .padding(14)
    }

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryFilterChip(title: "All", category: nil)

                ForEach(EditorCommandCategory.orderedCases.filter { $0 != .other }, id: \.rawValue) { category in
                    categoryFilterChip(title: category.displayTitle, category: category)
                }
            }
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if commandSections.isEmpty {
                        emptyState
                    } else {
                        if !recentCommands.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "Recently Used", table: "LumiEditor"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                                    .padding(.horizontal, 4)

                                ForEach(recentCommands) { command in
                                    Button {
                                        execute(command)
                                    } label: {
                                        row(for: command, emphasizeRecent: true)
                                    }
                                    .id(command.id)
                                    .buttonStyle(.plain)
                                    .disabled(!command.isEnabled)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedCommandID = command.id
                                        }
                                    }
                                }
                            }
                        }

                        ForEach(commandSections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                                    .padding(.horizontal, 4)

                                ForEach(section.commands) { command in
                                    Button {
                                        execute(command)
                                    } label: {
                                        row(for: command)
                                    }
                                    .id(command.id)
                                    .buttonStyle(.plain)
                                    .disabled(!command.isEnabled)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedCommandID = command.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: selectedCommandID) { _, commandID in
                guard let commandID else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(commandID, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            footerHint("↑↓", String(localized: "Navigate", table: "LumiEditor"))
            footerHint("Enter", String(localized: "Run", table: "LumiEditor"))
            footerHint("Esc", String(localized: "Close", table: "LumiEditor"))

            Spacer(minLength: 0)

            Text("\(flattenedCommands.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "No Matching Commands", table: "LumiEditor"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var commandSections: [EditorCommandSection] {
        presentationModel.sections
    }

    private var recentCommands: [EditorCommandSuggestion] {
        presentationModel.recentCommands
    }

    private var presentationModel: EditorCommandPresentationModel {
        if let selectedCategory {
            return state.editorCommandPresentationModel(
                categories: [selectedCategory],
                matching: query
            )
        }
        return state.editorCommandPresentationModel(matching: query)
    }

    private var flattenedCommands: [EditorCommandSuggestion] {
        presentationModel.flattenedCommands
    }

    private func footerHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AppUI.Color.semantic.textTertiary.opacity(0.08))
                )

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
    }

    private func categoryFilterChip(title: String, category: EditorCommandCategory?) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
            selectFirstCommandIfNeeded(force: true)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(
                    isSelected
                        ? AppUI.Color.semantic.primary
                        : AppUI.Color.semantic.textSecondary
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? AppUI.Color.semantic.primary.opacity(0.12)
                                : AppUI.Color.semantic.textTertiary.opacity(0.08)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? AppUI.Color.semantic.primary.opacity(0.35)
                                : AppUI.Color.semantic.textTertiary.opacity(0.14),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func row(for command: EditorCommandSuggestion, emphasizeRecent: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: command.systemImage)
                .font(.system(size: 11))
                .foregroundColor(command.isEnabled ? AppUI.Color.semantic.textSecondary : AppUI.Color.semantic.textTertiary)
                .frame(width: 16)

            if emphasizeRecent {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.primary)
            }

            Text(command.title)
                .font(.system(size: 12, weight: command.isEnabled ? .medium : .regular))
                .foregroundColor(command.isEnabled ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcut = command.shortcut {
                Text(shortcut.displayText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    selectedCommandID == command.id
                        ? AppUI.Color.semantic.primary.opacity(command.isEnabled ? 0.14 : 0.08)
                        : AppUI.Color.semantic.textTertiary.opacity(command.isEnabled ? 0.06 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedCommandID == command.id
                        ? AppUI.Color.semantic.primary.opacity(0.35)
                        : .clear,
                    lineWidth: 1
                )
        )
        .opacity(command.isEnabled ? 1 : 0.6)
    }

    private func execute(_ command: EditorCommandSuggestion) {
        guard command.isEnabled else { return }
        selectedCommandID = command.id
        state.performEditorCommand(id: command.id)
        onDismiss()
    }

    private func executeSelectedCommand() {
        guard let selectedCommand = flattenedCommands.first(where: { $0.id == selectedCommandID }) else {
            return
        }
        execute(selectedCommand)
    }

    private func selectFirstCommandIfNeeded(force: Bool = false) {
        guard force || selectedCommandID == nil else { return }
        selectedCommandID = flattenedCommands.first?.id
    }

    private func normalizeSelection() {
        if let selectedCommandID,
           flattenedCommands.contains(where: { $0.id == selectedCommandID }) {
            return
        }
        selectedCommandID = flattenedCommands.first?.id
    }

    private func moveSelection(by offset: Int) {
        guard !flattenedCommands.isEmpty else { return }
        guard let currentSelectionID = selectedCommandID,
              let currentIndex = flattenedCommands.firstIndex(where: { $0.id == currentSelectionID }) else {
            self.selectedCommandID = flattenedCommands.first?.id
            return
        }
        let nextIndex = max(0, min(flattenedCommands.count - 1, currentIndex + offset))
        selectedCommandID = flattenedCommands[nextIndex].id
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .upArrow:
            moveSelection(by: -1)
            return .handled
        case .downArrow:
            moveSelection(by: 1)
            return .handled
        case .return:
            executeSelectedCommand()
            return .handled
        case .escape:
            onDismiss()
            return .handled
        default:
            return .ignored
        }
    }
}
