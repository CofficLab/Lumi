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
    private var codeActionContributors: [any EditorCodeActionContributor] = []
    private var commandContributors: [any EditorCommandContributor] = []
    private var interactionContributors: [any EditorInteractionContributor] = []
    private var sidePanelContributors: [any EditorSidePanelContributor] = []
    private var sheetContributors: [any EditorSheetContributor] = []
    private var toolbarContributors: [any EditorToolbarContributor] = []

    func reset() {
        completionContributors.removeAll()
        hoverContributors.removeAll()
        codeActionContributors.removeAll()
        commandContributors.removeAll()
        interactionContributors.removeAll()
        sidePanelContributors.removeAll()
        sheetContributors.removeAll()
        toolbarContributors.removeAll()
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

    func registerCodeActionContributor(_ contributor: any EditorCodeActionContributor) {
        if codeActionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        codeActionContributors.append(contributor)
    }

    func registerCommandContributor(_ contributor: any EditorCommandContributor) {
        if commandContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        commandContributors.append(contributor)
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
        guard !hoverContributors.isEmpty else { return [] }
        var merged: [EditorHoverSuggestion] = []
        for contributor in hoverContributors {
            let items = await contributor.provideHover(context: context)
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

    func sidePanelSuggestions(state: EditorState) -> [EditorSidePanelSuggestion] {
        guard !sidePanelContributors.isEmpty else { return [] }
        var merged: [EditorSidePanelSuggestion] = []
        for contributor in sidePanelContributors {
            let items = contributor.provideSidePanels(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSidePanels(merged)
    }

    func sheetSuggestions(state: EditorState) -> [EditorSheetSuggestion] {
        guard !sheetContributors.isEmpty else { return [] }
        var merged: [EditorSheetSuggestion] = []
        for contributor in sheetContributors {
            let items = contributor.provideSheets(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSheets(merged)
    }

    func toolbarItemSuggestions(state: EditorState) -> [EditorToolbarItemSuggestion] {
        guard !toolbarContributors.isEmpty else { return [] }
        var merged: [EditorToolbarItemSuggestion] = []
        for contributor in toolbarContributors {
            let items = contributor.provideToolbarItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateToolbarItems(merged)
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
            let key = item.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
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
}
