import Foundation
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

/// 编辑器扩展注册中心
/// 目前先开放补全扩展点，后续可继续添加 hover/code action/toolbar 等扩展点。
///
/// ## 线程说明
/// - 注册/注销：@MainActor（与 View 生命周期一致）
/// - 同步查询（command/sidePanel/sheet/toolbar）：@MainActor
/// - 异步查询（completion/hover/codeAction）：委托给 `ExtensionResolver`（后台 actor）执行，
///   但保留当前同步版本以确保向后兼容。调用方可选择使用 `resolveCompletionAsync` 等方法
///   将聚合和去重放到后台线程。
@MainActor
final class EditorExtensionRegistry: ObservableObject {
    private var completionContributors: [any EditorCompletionContributor] = []
    private var hoverContributors: [any EditorHoverContributor] = []
    private var hoverContentContributors: [any EditorHoverContentContributor] = []
    private var codeActionContributors: [any EditorCodeActionContributor] = []
    private var highlightProviderContributors: [any EditorHighlightProviderContributor] = []
    private var commandContributors: [any EditorCommandContributor] = []
    private var contextMenuContributors: [any EditorContextMenuContributor] = []
    private var gutterDecorationContributors: [any EditorGutterDecorationContributor] = []
    private var panelContributors: [any EditorPanelContributor] = []
    private var settingsContributors: [any EditorSettingsContributor] = []
    private var statusItemContributors: [any EditorStatusItemContributor] = []
    private var quickOpenContributors: [any EditorQuickOpenContributor] = []
    private var interactionContributors: [any EditorInteractionContributor] = []
    private var sidePanelContributors: [any EditorSidePanelContributor] = []
    private var sheetContributors: [any EditorSheetContributor] = []
    private var toolbarContributors: [any EditorToolbarContributor] = []
    private var themeContributors: [any EditorThemeContributor] = []
    private var projectContextCapabilities: [any SuperEditorProjectContextCapability] = []
    private var languageIntegrationCapabilities: [any SuperEditorLanguageIntegrationCapability] = []
    private var semanticCapabilities: [any SuperEditorSemanticCapability] = []

    func reset() {
        completionContributors.removeAll()
        hoverContributors.removeAll()
        hoverContentContributors.removeAll()
        codeActionContributors.removeAll()
        highlightProviderContributors.removeAll()
        commandContributors.removeAll()
        contextMenuContributors.removeAll()
        gutterDecorationContributors.removeAll()
        panelContributors.removeAll()
        settingsContributors.removeAll()
        statusItemContributors.removeAll()
        quickOpenContributors.removeAll()
        interactionContributors.removeAll()
        sidePanelContributors.removeAll()
        sheetContributors.removeAll()
        toolbarContributors.removeAll()
        themeContributors.removeAll()
        projectContextCapabilities.removeAll()
        languageIntegrationCapabilities.removeAll()
        semanticCapabilities.removeAll()
    }

    func registerCompletionContributor(_ contributor: any EditorCompletionContributor) {
        if completionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        completionContributors.append(contributor)
    }

    func registerHoverContributor(_ contributor: any EditorHoverContributor) {
        if hoverContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        hoverContributors.append(contributor)
    }

    func registerHoverContentContributor(_ contributor: any EditorHoverContentContributor) {
        if hoverContentContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        hoverContentContributors.append(contributor)
    }

    func registerCodeActionContributor(_ contributor: any EditorCodeActionContributor) {
        if codeActionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        codeActionContributors.append(contributor)
    }

    func registerHighlightProviderContributor(_ contributor: any EditorHighlightProviderContributor) {
        if highlightProviderContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        highlightProviderContributors.append(contributor)
    }

    func registerCommandContributor(_ contributor: any EditorCommandContributor) {
        if commandContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        commandContributors.append(contributor)
    }

    func registerContextMenuContributor(_ contributor: any EditorContextMenuContributor) {
        if contextMenuContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        contextMenuContributors.append(contributor)
    }

    func registerGutterDecorationContributor(_ contributor: any EditorGutterDecorationContributor) {
        if gutterDecorationContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        gutterDecorationContributors.append(contributor)
    }

    func registerDecorationContributor(_ contributor: any EditorDecorationContributor) {
        registerGutterDecorationContributor(contributor)
    }

    func registerPanelContributor(_ contributor: any EditorPanelContributor) {
        if panelContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        panelContributors.append(contributor)
    }

    func registerSettingsContributor(_ contributor: any EditorSettingsContributor) {
        if settingsContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        settingsContributors.append(contributor)
    }

    func registerStatusItemContributor(_ contributor: any EditorStatusItemContributor) {
        if statusItemContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        statusItemContributors.append(contributor)
    }

    func registerQuickOpenContributor(_ contributor: any EditorQuickOpenContributor) {
        if quickOpenContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        quickOpenContributors.append(contributor)
    }

    func registerInteractionContributor(_ contributor: any EditorInteractionContributor) {
        if interactionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        interactionContributors.append(contributor)
    }

    func registerSidePanelContributor(_ contributor: any EditorSidePanelContributor) {
        if sidePanelContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        sidePanelContributors.append(contributor)
    }

    func registerSheetContributor(_ contributor: any EditorSheetContributor) {
        if sheetContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        sheetContributors.append(contributor)
    }

    func registerToolbarContributor(_ contributor: any EditorToolbarContributor) {
        if toolbarContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        toolbarContributors.append(contributor)
    }

    // MARK: - Editor Capabilities (内核内部能力聚合)

    func registerProjectContextCapability(_ capability: any SuperEditorProjectContextCapability) {
        if projectContextCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        projectContextCapabilities.append(capability)
    }

    func registerLanguageIntegrationCapability(_ capability: any SuperEditorLanguageIntegrationCapability) {
        if languageIntegrationCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        languageIntegrationCapabilities.append(capability)
    }

    func registerSemanticCapability(_ capability: any SuperEditorSemanticCapability) {
        if semanticCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        semanticCapabilities.append(capability)
    }

    /// 按项目路径查找最匹配的项目上下文能力
    func projectContextCapability(for projectPath: String?) -> (any SuperEditorProjectContextCapability)? {
        bestMatch(in: projectContextCapabilities.filter { $0.canHandleProject(at: projectPath) })
    }

    /// 按语言和项目路径查找最匹配的语言集成能力
    func languageIntegrationCapability(
        for languageId: String,
        projectPath: String?
    ) -> (any SuperEditorLanguageIntegrationCapability)? {
        bestMatch(
            in: languageIntegrationCapabilities.filter { $0.supports(languageId: languageId, projectPath: projectPath) }
        )
    }

    /// 按 URI 查找最匹配的语义可用性能力
    func semanticCapability(for uri: String?) -> (any SuperEditorSemanticCapability)? {
        bestMatch(in: semanticCapabilities.filter { $0.canHandle(uri: uri) })
    }

    // MARK: - Theme

    func registerThemeContributor(_ contributor: any EditorThemeContributor) {
        if themeContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        themeContributors.append(contributor)
        themeContributors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// 所有已注册的主题（按 displayName 排序）
    func allThemes() -> [any EditorThemeContributor] {
        themeContributors
    }

    /// 按 ID 查找主题
    func theme(for id: String) -> (any EditorThemeContributor)? {
        themeContributors.first { $0.id == id }
    }

    func completionSuggestions(for context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard !completionContributors.isEmpty else { return [] }
        var merged: [EditorCompletionSuggestion] = []
        for contributor in completionContributors {
            let items = await contributor.provideSuggestions(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSuggestions(merged)
    }

    func hoverSuggestions(for context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard !hoverContributors.isEmpty || !hoverContentContributors.isEmpty else { return [] }
        var merged: [EditorHoverSuggestion] = []
        for contributor in hoverContributors {
            let items = await contributor.provideHover(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        for contributor in hoverContentContributors {
            let items = await contributor.provideHoverContent(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateHovers(merged)
    }

    func codeActionSuggestions(for context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        guard !codeActionContributors.isEmpty else { return [] }
        var merged: [EditorCodeActionSuggestion] = []
        for contributor in codeActionContributors {
            let items = await contributor.provideCodeActions(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateCodeActions(merged)
    }

    func commandSuggestions(
        for context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard !commandContributors.isEmpty else { return [] }
        var merged: [EditorCommandSuggestion] = []
        for contributor in commandContributors {
            let items = contributor.provideCommands(
                context: context,
                state: state,
                textView: textView
            )
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateCommands(merged)
    }

    func contextMenuSuggestions(
        for context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorContextMenuItemSuggestion] {
        let contributionContext = makeContributionContext(
            state: state,
            legacyContext: context
        )

        var merged = commandSuggestions(
            for: context,
            state: state,
            textView: textView
        ).map(EditorContextMenuItemSuggestion.init(command:))

        for contributor in contextMenuContributors {
            let items = contributor.provideContextMenuItems(
                context: context,
                state: state,
                textView: textView
            )
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateContextMenuSuggestions(
            merged.filter { $0.isEnabled && $0.metadata.matches(contributionContext) }
        )
    }

    func gutterDecorationSuggestions(
        for context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        guard !gutterDecorationContributors.isEmpty else { return [] }
        var merged: [EditorGutterDecorationSuggestion] = []
        for contributor in gutterDecorationContributors {
            let items = contributor.provideGutterDecorations(context: context, state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateGutterDecorations(merged)
    }

    func sidePanelSuggestions(state: EditorState) -> [EditorSidePanelSuggestion] {
        var merged: [EditorSidePanelSuggestion] = []
        for panel in panelSuggestions(state: state) where panel.placement == .side {
            merged.append(
                EditorSidePanelSuggestion(
                    id: panel.id,
                    order: panel.order,
                    isPresented: panel.isPresented,
                    content: panel.content
                )
            )
        }
        for contributor in sidePanelContributors {
            let items = contributor.provideSidePanels(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSidePanels(merged)
    }

    func sheetSuggestions(state: EditorState) -> [EditorSheetSuggestion] {
        var merged: [EditorSheetSuggestion] = []
        for panel in panelSuggestions(state: state) where panel.placement == .sheet {
            merged.append(
                EditorSheetSuggestion(
                    id: panel.id,
                    order: panel.order,
                    isPresented: panel.isPresented,
                    onDismiss: panel.onDismiss,
                    content: panel.content
                )
            )
        }
        for contributor in sheetContributors {
            let items = contributor.provideSheets(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSheets(merged)
    }

    func panelSuggestions(state: EditorState) -> [EditorPanelSuggestion] {
        guard !panelContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorPanelSuggestion] = []
        for contributor in panelContributors {
            let items = contributor.providePanels(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicatePanels(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    func settingsSuggestions(state: EditorSettingsState) -> [EditorSettingsItemSuggestion] {
        guard !settingsContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorSettingsItemSuggestion] = []
        for contributor in settingsContributors {
            let items = contributor.provideSettingsItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSettingsItems(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    func toolbarItemSuggestions(state: EditorState) -> [EditorToolbarItemSuggestion] {
        var merged: [EditorToolbarItemSuggestion] = []
        for item in statusItemSuggestions(state: state)
        where item.placement == .toolbarCenter || item.placement == .toolbarTrailing {
            merged.append(EditorToolbarItemSuggestion(statusItem: item))
        }
        for contributor in toolbarContributors {
            let items = contributor.provideToolbarItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateToolbarItems(merged)
    }

    func statusItemSuggestions(state: EditorState) -> [EditorStatusItemSuggestion] {
        guard !statusItemContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorStatusItemSuggestion] = []
        for contributor in statusItemContributors {
            let items = contributor.provideStatusItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateStatusItems(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    func quickOpenSuggestions(
        matching query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !quickOpenContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)

        var merged: [EditorQuickOpenItemSuggestion] = []
        for contributor in quickOpenContributors {
            let items = await contributor.provideQuickOpenItems(query: trimmedQuery, state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateQuickOpenItems(
            merged.filter { $0.isEnabled && $0.metadata.matches(contributionContext) }
        )
    }

    private func makeContributionContext(
        state: EditorState,
        legacyContext: EditorCommandContext? = nil
    ) -> EditorContributionContext {
        EditorContributionContext(
            languageId: legacyContext?.languageId ?? state.detectedLanguage?.tsName ?? "swift",
            fileURL: state.currentFileURL,
            hasSelection: legacyContext?.hasSelection ?? false,
            line: legacyContext?.line ?? max(state.cursorLine - 1, 0),
            character: legacyContext?.character ?? max(state.cursorColumn - 1, 0),
            isEditorActive: state.currentFileURL != nil,
            isLargeFileMode: state.largeFileMode != .normal
        )
    }

    private func makeContributionContext(state: EditorSettingsState) -> EditorContributionContext {
        EditorContributionContext(
            languageId: "settings",
            fileURL: nil,
            hasSelection: false,
            line: 0,
            character: 0,
            isEditorActive: false,
            isLargeFileMode: false
        )
    }

    func highlightProviders(for languageId: String) -> [any HighlightProviding] {
        guard !highlightProviderContributors.isEmpty else { return [] }

        var merged: [any HighlightProviding] = []
        var seenProviderIDs: Set<ObjectIdentifier> = []

        for contributor in highlightProviderContributors where contributor.supports(languageId: languageId) {
            for provider in contributor.provideHighlightProviders(languageId: languageId) {
                let providerID = ObjectIdentifier(provider)
                if seenProviderIDs.insert(providerID).inserted {
                    merged.append(provider)
                }
            }
        }

        return merged
    }

    func runInteractionTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard !interactionContributors.isEmpty else { return }
        for contributor in interactionContributors {
            await contributor.onTextDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }

    func runInteractionSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard !interactionContributors.isEmpty else { return }
        for contributor in interactionContributors {
            await contributor.onSelectionDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }

    private func deduplicateSuggestions(_ suggestions: [EditorCompletionSuggestion]) -> [EditorCompletionSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCompletionSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        for item in sorted {
            let key = item.label.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateHovers(_ suggestions: [EditorHoverSuggestion]) -> [EditorHoverSuggestion] {
        var seen: Set<String> = []
        var result: [EditorHoverSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            lhs.priority > rhs.priority
        }

        for item in sorted {
            let key = (item.dedupeKey ?? item.markdown).trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateCodeActions(_ suggestions: [EditorCodeActionSuggestion]) -> [EditorCodeActionSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCodeActionSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateCommands(_ suggestions: [EditorCommandSuggestion]) -> [EditorCommandSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCommandSuggestion] = []
        let sorted = suggestions.sortedForCommandPresentation()

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateContextMenuSuggestions(_ suggestions: [EditorContextMenuItemSuggestion]) -> [EditorContextMenuItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorContextMenuItemSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            let lhsCommand = lhs.asCommandSuggestion
            let rhsCommand = rhs.asCommandSuggestion
            if lhsCommand.order != rhsCommand.order {
                return lhsCommand.order < rhsCommand.order
            }
            return lhsCommand.title.localizedCaseInsensitiveCompare(rhsCommand.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateGutterDecorations(_ suggestions: [EditorGutterDecorationSuggestion]) -> [EditorGutterDecorationSuggestion] {
        var seen: Set<String> = []
        var result: [EditorGutterDecorationSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            if lhs.lane != rhs.lane { return lhs.lane < rhs.lane }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.line):\(item.lane):\(item.id.lowercased())"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateSidePanels(_ suggestions: [EditorSidePanelSuggestion]) -> [EditorSidePanelSuggestion] {
        var seen: Set<String> = []
        var result: [EditorSidePanelSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicatePanels(_ suggestions: [EditorPanelSuggestion]) -> [EditorPanelSuggestion] {
        var seen: Set<String> = []
        var result: [EditorPanelSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.placement != rhs.placement {
                return lhs.placement.rawValue.localizedCaseInsensitiveCompare(rhs.placement.rawValue) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.placement.rawValue):\((item.metadata.dedupeKey ?? item.id).lowercased())"
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateSheets(_ suggestions: [EditorSheetSuggestion]) -> [EditorSheetSuggestion] {
        var seen: Set<String> = []
        var result: [EditorSheetSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateToolbarItems(_ suggestions: [EditorToolbarItemSuggestion]) -> [EditorToolbarItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorToolbarItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateSettingsItems(_ suggestions: [EditorSettingsItemSuggestion]) -> [EditorSettingsItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorSettingsItemSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.sectionTitle != rhs.sectionTitle {
                return lhs.sectionTitle.localizedCaseInsensitiveCompare(rhs.sectionTitle) == .orderedAscending
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateStatusItems(_ suggestions: [EditorStatusItemSuggestion]) -> [EditorStatusItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorStatusItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.placement != rhs.placement {
                return lhs.placement.rawValue.localizedCaseInsensitiveCompare(rhs.placement.rawValue) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.placement.rawValue):\((item.metadata.dedupeKey ?? item.id).lowercased())"
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateQuickOpenItems(_ suggestions: [EditorQuickOpenItemSuggestion]) -> [EditorQuickOpenItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorQuickOpenItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.sectionTitle != rhs.sectionTitle {
                return lhs.sectionTitle.localizedCaseInsensitiveCompare(rhs.sectionTitle) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func bestMatch(
        in providers: [any SuperEditorProjectContextCapability]
    ) -> (any SuperEditorProjectContextCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }

    private func bestMatch(
        in providers: [any SuperEditorLanguageIntegrationCapability]
    ) -> (any SuperEditorLanguageIntegrationCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }

    private func bestMatch(
        in providers: [any SuperEditorSemanticCapability]
    ) -> (any SuperEditorSemanticCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }
}
