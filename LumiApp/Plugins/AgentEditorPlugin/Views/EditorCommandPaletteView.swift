import SwiftUI
import MagicKit
import CodeEditSourceEditor

struct EditorCommandPaletteView: View {
    @ObservedObject var state: EditorState
    let openEditors: [EditorOpenEditorItem]
    let onOpenFile: (URL, CursorPosition?, Bool) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedItemID: String?
    @State private var selectedCategory: EditorCommandCategory?
    @State private var quickOpenItems: [EditorQuickOpenItemSuggestion] = []
    @State private var quickOpenRefreshTask: Task<Void, Never>?
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
            selectedCategory = state.preferredCommandPaletteCategory()
            refreshQuickOpenItems()
            selectFirstItemIfNeeded()
        }
        .onChange(of: flattenedCommands.map(\.id)) { _, _ in
            normalizeSelection()
        }
        .onChange(of: query) { _, _ in
            refreshQuickOpenItems()
        }
        .onChange(of: selectedCategory) { _, _ in
            state.setPreferredCommandPaletteCategory(selectedCategory)
            refreshQuickOpenItems()
        }
        .onDisappear {
            quickOpenRefreshTask?.cancel()
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
                String(localized: "Quick Open: files, @symbols, #workspace, :line, >commands", table: "LumiEditor"),
                text: $query
            )
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .onSubmit {
                executeSelectedItem()
            }

            if shouldShowCategoryFilter {
                categoryFilterStrip
            }
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
                    if quickOpenSections.isEmpty && commandSections.isEmpty && recentCommands.isEmpty {
                        emptyState
                    } else {
                        quickOpenSectionViews

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
                                        commandRow(for: command, emphasizeRecent: true)
                                    }
                                    .id(commandSelectionID(for: command))
                                    .buttonStyle(.plain)
                                    .disabled(!command.isEnabled)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedItemID = commandSelectionID(for: command)
                                        }
                                    }
                                }
                            }
                        }

                        if !frequentCommands.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "Frequently Used", table: "LumiEditor"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                                    .padding(.horizontal, 4)

                                ForEach(frequentCommands) { command in
                                    Button {
                                        execute(command)
                                    } label: {
                                        commandRow(for: command, emphasizeFrequent: true)
                                    }
                                    .id(commandSelectionID(for: command))
                                    .buttonStyle(.plain)
                                    .disabled(!command.isEnabled)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedItemID = commandSelectionID(for: command)
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
                                        commandRow(for: command)
                                    }
                                    .id(commandSelectionID(for: command))
                                    .buttonStyle(.plain)
                                    .disabled(!command.isEnabled)
                                    .onHover { hovering in
                                        if hovering {
                                            selectedItemID = commandSelectionID(for: command)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: selectedItemID) { _, itemID in
                guard let itemID else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(itemID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var quickOpenSectionViews: some View {
        ForEach(quickOpenSections) { section in
            VStack(alignment: .leading, spacing: 6) {
                Text(section.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .padding(.horizontal, 4)

                ForEach(section.items) { item in
                    Button {
                        execute(item)
                    } label: {
                        quickOpenRow(for: item)
                    }
                    .id(quickOpenSelectionID(for: item))
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .onHover { hovering in
                        if hovering {
                            selectedItemID = quickOpenSelectionID(for: item)
                        }
                    }
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

            Text("\(flattenedSelectionIDs.count)")
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

            Text(String(localized: "No Matching Results", table: "LumiEditor"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var quickOpenQuery: EditorQuickOpenQuery {
        state.quickOpenQuery(for: query)
    }

    private var shouldShowCategoryFilter: Bool {
        quickOpenQuery.scope == .commands || !quickOpenQuery.hasExplicitScope
    }

    private var commandSections: [EditorCommandSection] {
        shouldShowCommandResults ? presentationModel.sections : []
    }

    private var recentCommands: [EditorCommandSuggestion] {
        shouldShowCommandResults ? presentationModel.recentCommands : []
    }

    private var frequentCommands: [EditorCommandSuggestion] {
        shouldShowCommandResults ? presentationModel.frequentCommands : []
    }

    private var presentationModel: EditorCommandPresentationModel {
        let commandQuery = quickOpenQuery.scope == .commands ? quickOpenQuery.searchText : query
        if let selectedCategory {
            return state.editorCommandPresentationModel(
                categories: [selectedCategory],
                matching: commandQuery
            )
        }
        return state.editorCommandPresentationModel(matching: commandQuery)
    }

    private var shouldShowCommandResults: Bool {
        quickOpenQuery.scope == .commands || !quickOpenQuery.hasExplicitScope
    }

    private var quickOpenSections: [QuickOpenSection] {
        guard selectedCategory == nil else { return [] }

        let grouped = Dictionary(grouping: quickOpenItems, by: \.sectionTitle)
        return grouped.keys.sorted().map { title in
            QuickOpenSection(
                title: title,
                items: grouped[title, default: []].sorted { lhs, rhs in
                    if lhs.order != rhs.order { return lhs.order < rhs.order }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            )
        }
    }

    private var flattenedCommands: [EditorCommandSuggestion] {
        presentationModel.flattenedCommands
    }

    private var flattenedSelectionIDs: [String] {
        quickOpenSections.flatMap { section in
            section.items.map(quickOpenSelectionID(for:))
        } + flattenedCommands.map(commandSelectionID(for:))
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
            selectFirstItemIfNeeded(force: true)
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

    private func commandRow(
        for command: EditorCommandSuggestion,
        emphasizeRecent: Bool = false,
        emphasizeFrequent: Bool = false
    ) -> some View {
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

            if emphasizeFrequent {
                Image(systemName: "flame")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
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
                    selectedItemID == commandSelectionID(for: command)
                        ? AppUI.Color.semantic.primary.opacity(command.isEnabled ? 0.14 : 0.08)
                        : AppUI.Color.semantic.textTertiary.opacity(command.isEnabled ? 0.06 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedItemID == commandSelectionID(for: command)
                        ? AppUI.Color.semantic.primary.opacity(0.35)
                        : .clear,
                    lineWidth: 1
                )
        )
        .opacity(command.isEnabled ? 1 : 0.6)
    }

    private func quickOpenRow(for item: EditorQuickOpenItemSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11))
                .foregroundColor(item.isEnabled ? AppUI.Color.semantic.textSecondary : AppUI.Color.semantic.textTertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: item.isEnabled ? .medium : .regular))
                    .foregroundColor(item.isEnabled ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .lineLimit(1)
                }
            }

            if let badge = item.badge {
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppUI.Color.semantic.textTertiary.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    selectedItemID == quickOpenSelectionID(for: item)
                        ? AppUI.Color.semantic.primary.opacity(item.isEnabled ? 0.14 : 0.08)
                        : AppUI.Color.semantic.textTertiary.opacity(item.isEnabled ? 0.06 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedItemID == quickOpenSelectionID(for: item)
                        ? AppUI.Color.semantic.primary.opacity(0.35)
                        : .clear,
                    lineWidth: 1
                )
        )
        .opacity(item.isEnabled ? 1 : 0.6)
    }

    private func execute(_ command: EditorCommandSuggestion) {
        guard command.isEnabled else { return }
        selectedItemID = commandSelectionID(for: command)
        state.performEditorCommand(id: command.id)
        onDismiss()
    }

    private func execute(_ item: EditorQuickOpenItemSuggestion) {
        guard item.isEnabled else { return }
        selectedItemID = quickOpenSelectionID(for: item)
        item.action()
        onDismiss()
    }

    private func executeSelectedItem() {
        guard let selectedItemID else { return }

        if let quickOpenItem = quickOpenItems.first(where: { quickOpenSelectionID(for: $0) == selectedItemID }) {
            execute(quickOpenItem)
            return
        }

        guard let selectedCommand = flattenedCommands.first(where: { commandSelectionID(for: $0) == selectedItemID }) else {
            return
        }
        execute(selectedCommand)
    }

    private func selectFirstItemIfNeeded(force: Bool = false) {
        guard force || selectedItemID == nil else { return }
        selectedItemID = flattenedSelectionIDs.first
    }

    private func normalizeSelection() {
        if let selectedItemID, flattenedSelectionIDs.contains(selectedItemID) {
            return
        }
        selectedItemID = flattenedSelectionIDs.first
    }

    private func moveSelection(by offset: Int) {
        guard !flattenedSelectionIDs.isEmpty else { return }
        guard let currentSelectionID = selectedItemID,
              let currentIndex = flattenedSelectionIDs.firstIndex(of: currentSelectionID) else {
            selectedItemID = flattenedSelectionIDs.first
            return
        }
        let nextIndex = max(0, min(flattenedSelectionIDs.count - 1, currentIndex + offset))
        selectedItemID = flattenedSelectionIDs[nextIndex]
    }

    private func refreshQuickOpenItems() {
        quickOpenRefreshTask?.cancel()

        guard selectedCategory == nil || quickOpenQuery.hasExplicitScope else {
            quickOpenItems = []
            return
        }

        let currentQuery = query
        let currentOpenEditors = openEditors
        quickOpenRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            quickOpenItems = await state.editorQuickOpenItems(
                matching: currentQuery,
                openEditors: currentOpenEditors,
                onOpenFile: onOpenFile
            )
            normalizeSelection()
        }
    }

    private func commandSelectionID(for command: EditorCommandSuggestion) -> String {
        "command:\(command.id)"
    }

    private func quickOpenSelectionID(for item: EditorQuickOpenItemSuggestion) -> String {
        "quick:\(item.id)"
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
            executeSelectedItem()
            return .handled
        case .escape:
            onDismiss()
            return .handled
        default:
            return .ignored
        }
    }
}

private struct QuickOpenSection: Identifiable {
    let title: String
    let items: [EditorQuickOpenItemSuggestion]

    var id: String { title }
}
