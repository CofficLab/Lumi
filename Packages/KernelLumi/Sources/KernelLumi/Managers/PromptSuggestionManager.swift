import Foundation

/// 提示词聚合服务的内核默认实现。
///
/// 维护一份按 `id` 去重的提示词列表：外部快照 `allPromptSuggestions` 按 `order`
/// 排序，`order` 相同时保持插入顺序（即插件返回顺序）。任何注册/注销/清空操作
/// 都会触发 `objectWillChange`，便于 SwiftUI 消费视图响应式刷新。
@MainActor
public final class PromptSuggestionManager: ObservableObject, PromptSuggestionProviding {
    /// 所有已注册的提示词（按 `order` 排序，同 `order` 保持插入顺序）。
    public private(set) var allPromptSuggestions: [LumiPromptSuggestion] = []

    private var suggestions: [String: LumiPromptSuggestion] = [:]

    /// 插入顺序的 `id` 列表，用于在 `order` 相同时稳定保持插件返回顺序。
    private var insertionOrder: [String] = []

    public init() {}

    public func registerPromptSuggestion(_ suggestion: LumiPromptSuggestion) {
        if suggestions[suggestion.id] == nil {
            insertionOrder.append(suggestion.id)
        }
        suggestions[suggestion.id] = suggestion
        rebuild()
    }

    public func unregisterPromptSuggestion(id: String) {
        guard suggestions.removeValue(forKey: id) != nil else { return }
        insertionOrder.removeAll { $0 == id }
        rebuild()
    }

    public func clearAllContributions() {
        guard !suggestions.isEmpty else { return }
        suggestions.removeAll()
        insertionOrder.removeAll()
        rebuild()
    }

    private func rebuild() {
        objectWillChange.send()

        // Swift 的 `sorted` 不保证稳定，因此用插入下标作为同 `order` 的 tie-break，
        // 以稳定保持每个插件返回的提示词顺序。
        allPromptSuggestions = insertionOrder
            .enumerated()
            .compactMap { (index, id) in suggestions[id].map { (index, $0) } }
            .sorted { lhs, rhs in
                if lhs.1.order != rhs.1.order {
                    return lhs.1.order < rhs.1.order
                }
                return lhs.0 < rhs.0
            }
            .map { $0.1 }
    }
}
