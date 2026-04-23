import Foundation
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

/// 编辑器补全上下文
@MainActor
struct EditorCompletionContext {
    let languageId: String
    let line: Int
    let character: Int
    let prefix: String
    let isTypeContext: Bool
}

/// 编辑器补全建议（由扩展提供）
@MainActor
struct EditorCompletionSuggestion: Hashable {
    let label: String
    let insertText: String
    let detail: String?
    let priority: Int
}

/// 编辑器补全扩展点
@MainActor
protocol EditorCompletionContributor: AnyObject {
    var id: String { get }
    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion]
}

/// 编辑器悬停上下文
@MainActor
struct EditorHoverContext {
    let languageId: String
    let line: Int
    let character: Int
    let symbol: String
}

/// 编辑器悬停建议
@MainActor
struct EditorHoverSuggestion: Hashable {
    let markdown: String
    let priority: Int
}

/// 编辑器悬停扩展点
@MainActor
protocol EditorHoverContributor: AnyObject {
    var id: String { get }
    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion]
}

/// 编辑器代码动作上下文
@MainActor
struct EditorCodeActionContext {
    let languageId: String
    let line: Int
    let character: Int
    let selectedText: String?
}

/// 编辑器代码动作建议
@MainActor
struct EditorCodeActionSuggestion: Hashable {
    let id: String
    let title: String
    let command: String
    let priority: Int
}

/// 编辑器代码动作扩展点
@MainActor
protocol EditorCodeActionContributor: AnyObject {
    var id: String { get }
    func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion]
}

/// 编辑器命令上下文
@MainActor
struct EditorCommandContext {
    let languageId: String
    let hasSelection: Bool
    let line: Int
    let character: Int
}

/// 编辑器命令建议
@MainActor
struct EditorCommandSuggestion: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let order: Int
    let isEnabled: Bool
    let action: () -> Void
}

/// 编辑器命令扩展点
@MainActor
protocol EditorCommandContributor: AnyObject {
    var id: String { get }
    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion]
}

/// 编辑器侧边面板建议（如 References / Problems）
@MainActor
struct EditorSidePanelSuggestion: Identifiable {
    let id: String
    let order: Int
    let isPresented: (EditorState) -> Bool
    let content: (EditorState) -> AnyView
}

/// 编辑器侧边面板扩展点
@MainActor
protocol EditorSidePanelContributor: AnyObject {
    var id: String { get }
    func provideSidePanels(state: EditorState) -> [EditorSidePanelSuggestion]
}

/// 编辑器弹窗建议（Sheet）
@MainActor
struct EditorSheetSuggestion: Identifiable {
    let id: String
    let order: Int
    let isPresented: (EditorState) -> Bool
    let onDismiss: (EditorState) -> Void
    let content: (EditorState) -> AnyView
}

/// 编辑器弹窗扩展点（Sheet）
@MainActor
protocol EditorSheetContributor: AnyObject {
    var id: String { get }
    func provideSheets(state: EditorState) -> [EditorSheetSuggestion]
}

/// 编辑器工具栏项建议
@MainActor
struct EditorToolbarItemSuggestion: Identifiable {
    enum Placement {
        case center
        case trailing
    }

    let id: String
    let order: Int
    let placement: Placement
    let content: (EditorState) -> AnyView
}

/// 编辑器工具栏扩展点
@MainActor
protocol EditorToolbarContributor: AnyObject {
    var id: String { get }
    func provideToolbarItems(state: EditorState) -> [EditorToolbarItemSuggestion]
}

/// 编辑器交互上下文（文本/选区变化）
@MainActor
struct EditorInteractionContext {
    let languageId: String
    let line: Int
    let character: Int
    let typedCharacter: String?
}

/// 编辑器交互扩展点
@MainActor
protocol EditorInteractionContributor: AnyObject {
    var id: String { get }
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async
}

extension EditorInteractionContributor {
    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}

    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {}
}

/// 编辑器扩展注册中心
/// 目前先开放补全扩展点，后续可继续添加 hover/code action/toolbar 等扩展点。
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

/// 内置示例扩展：Swift 原生类型补全
/// 目的：在类型上下文（例如 `let id: In`）时优先给出 Int/Int8/Int32 等建议。
@MainActor
final class SwiftPrimitiveTypeCompletionContributor: EditorCompletionContributor {
    let id = "builtin.swift.primitive-types"

    private static let primitiveTypes: [EditorCompletionSuggestion] = [
        .init(label: "Int", insertText: "Int", detail: "Swift Standard Type", priority: 1000),
        .init(label: "Int8", insertText: "Int8", detail: "Swift Standard Type", priority: 995),
        .init(label: "Int16", insertText: "Int16", detail: "Swift Standard Type", priority: 994),
        .init(label: "Int32", insertText: "Int32", detail: "Swift Standard Type", priority: 993),
        .init(label: "Int64", insertText: "Int64", detail: "Swift Standard Type", priority: 992),
        .init(label: "UInt", insertText: "UInt", detail: "Swift Standard Type", priority: 991),
        .init(label: "UInt8", insertText: "UInt8", detail: "Swift Standard Type", priority: 990),
        .init(label: "UInt16", insertText: "UInt16", detail: "Swift Standard Type", priority: 989),
        .init(label: "UInt32", insertText: "UInt32", detail: "Swift Standard Type", priority: 988),
        .init(label: "UInt64", insertText: "UInt64", detail: "Swift Standard Type", priority: 987),
        .init(label: "Float", insertText: "Float", detail: "Swift Standard Type", priority: 980),
        .init(label: "Double", insertText: "Double", detail: "Swift Standard Type", priority: 979),
        .init(label: "Bool", insertText: "Bool", detail: "Swift Standard Type", priority: 978),
        .init(label: "String", insertText: "String", detail: "Swift Standard Type", priority: 977)
    ]

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard context.languageId.lowercased() == "swift" else { return [] }
        guard context.isTypeContext else { return [] }
        let prefix = context.prefix.lowercased()
        guard !prefix.isEmpty else { return Self.primitiveTypes }
        return Self.primitiveTypes.filter { $0.label.lowercased().hasPrefix(prefix) }
    }
}
