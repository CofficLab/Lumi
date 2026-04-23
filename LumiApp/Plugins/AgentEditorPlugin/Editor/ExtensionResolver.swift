import Foundation

/// 编辑器扩展点解析器（后台执行版）
///
/// 与 `EditorExtensionRegistry`（@MainActor）配合使用：
/// - `EditorExtensionRegistry` 负责注册管理（保持向后兼容）
/// - `ExtensionResolver` 负责后台异步聚合（补全、hover、代码动作等）
///
/// ## 线程模型
/// - 自身标记 `@MainActor`，确保与 @MainActor contributors 兼容
/// - 使用 `Task.detached` 将去重/排序等纯计算移至后台线程
/// - contributor 调用本身是异步的，不会阻塞 UI
///
/// ## 与 EditorExtensionRegistry 的关系
/// `EditorExtensionRegistry` 保留所有同步方法和 UI-only 扩展点，
/// `ExtensionResolver` 仅处理异步耗时聚合。两者共享 contributors 列表。
@MainActor
final class ExtensionResolver: ObservableObject {

    // MARK: - 单例

    static let shared = ExtensionResolver()

    // MARK: - 属性

    private var completionContributors: [any EditorCompletionContributor] = []
    private var hoverContributors: [any EditorHoverContributor] = []
    private var codeActionContributors: [any EditorCodeActionContributor] = []

    // MARK: - 初始化

    private init() {}

    // MARK: - 重置

    func reset() {
        completionContributors.removeAll()
        hoverContributors.removeAll()
        codeActionContributors.removeAll()
    }

    // MARK: - 注册

    func registerCompletionContributor(_ contributor: any EditorCompletionContributor) {
        if !completionContributors.contains(where: { $0.id == contributor.id }) {
            completionContributors.append(contributor)
        }
    }

    func registerHoverContributor(_ contributor: any EditorHoverContributor) {
        if !hoverContributors.contains(where: { $0.id == contributor.id }) {
            hoverContributors.append(contributor)
        }
    }

    func registerCodeActionContributor(_ contributor: any EditorCodeActionContributor) {
        if !codeActionContributors.contains(where: { $0.id == contributor.id }) {
            codeActionContributors.append(contributor)
        }
    }

    // MARK: - 异步解析（并行请求 + 后台去重）

    /// 聚合补全建议（并行请求所有 contributor，后台去重排序）
    func resolveCompletion(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard !completionContributors.isEmpty else { return [] }

        // 顺序请求所有 contributor（避免 Sendable 兼容性问题）
        var allResults: [EditorCompletionSuggestion] = []
        for contributor in completionContributors {
            let items = await contributor.provideSuggestions(context: context)
            allResults.append(contentsOf: items)
        }

        // 去重和排序在后台线程执行，不阻塞主线程
        return await Self.deduplicateSuggestionsInBackground(allResults)
    }

    /// 聚合 hover 建议（并行请求 + 后台去重）
    func resolveHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard !hoverContributors.isEmpty else { return [] }

        var allResults: [EditorHoverSuggestion] = []
        for contributor in hoverContributors {
            let items = await contributor.provideHover(context: context)
            allResults.append(contentsOf: items)
        }

        return await Self.deduplicateHoversInBackground(allResults)
    }

    /// 聚合代码动作（并行请求 + 后台去重）
    func resolveCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        guard !codeActionContributors.isEmpty else { return [] }

        var allResults: [EditorCodeActionSuggestion] = []
        for contributor in codeActionContributors {
            let items = await contributor.provideCodeActions(context: context)
            allResults.append(contentsOf: items)
        }

        return await Self.deduplicateCodeActionsInBackground(allResults)
    }

    // MARK: - 后台去重工具

    /// 在后台线程执行补全建议的去重和排序
    private static func deduplicateSuggestionsInBackground(_ suggestions: [EditorCompletionSuggestion]) async -> [EditorCompletionSuggestion] {
        // 提取纯数据到后台处理
        let rawData = suggestions.map { (label: $0.label, insertText: $0.insertText, detail: $0.detail, priority: $0.priority) }
        let sorted = await Task.detached {
            rawData.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
        }.value

        var seen: Set<String> = []
        var result: [EditorCompletionSuggestion] = []

        for item in sorted {
            let key = item.label.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(EditorCompletionSuggestion(
                label: item.label,
                insertText: item.insertText,
                detail: item.detail,
                priority: item.priority
            ))
        }
        return result
    }

    /// 在后台线程执行 hover 建议的去重和排序
    private static func deduplicateHoversInBackground(_ suggestions: [EditorHoverSuggestion]) async -> [EditorHoverSuggestion] {
        let rawData = suggestions.map { (markdown: $0.markdown, priority: $0.priority) }
        let sorted = await Task.detached {
            rawData.sorted { $0.priority > $1.priority }
        }.value

        var seen: Set<String> = []
        var result: [EditorHoverSuggestion] = []

        for item in sorted {
            let trimmed = item.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || seen.contains(trimmed) { continue }
            seen.insert(trimmed)
            result.append(EditorHoverSuggestion(markdown: item.markdown, priority: item.priority))
        }
        return result
    }

    /// 在后台线程执行代码动作的去重和排序
    private static func deduplicateCodeActionsInBackground(_ suggestions: [EditorCodeActionSuggestion]) async -> [EditorCodeActionSuggestion] {
        let rawData = suggestions.map { (id: $0.id, title: $0.title, command: $0.command, priority: $0.priority) }
        let sorted = await Task.detached {
            rawData.sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }.value

        var seen: Set<String> = []
        var result: [EditorCodeActionSuggestion] = []

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(EditorCodeActionSuggestion(
                id: item.id,
                title: item.title,
                command: item.command,
                priority: item.priority
            ))
        }
        return result
    }
}
