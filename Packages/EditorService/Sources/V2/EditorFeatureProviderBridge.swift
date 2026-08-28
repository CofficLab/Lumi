import Foundation
import EditorContracts

// MARK: - Feature Provider 桥（契约 V2，Phase 5 §10）
//
// 把插件贡献的中立 `EditorFeatureProvider`（completion/hover/codeAction/quickOpen）
// 适配到 EditorService 现有 SuperEditor 贡献者管线。Provider 不感知 EditorService；
// 聚合/去重/排序仍由 EditorService 现有 resolver 完成（§9.5）。

/// 桥接所需的宿主上下文（由 `EditorProvidingV2Adapter` 提供）。
@MainActor
public protocol EditorFeatureHostBridge: AnyObject {
    /// 当前活动文档的请求上下文（languageID 由调用方从 SuperEditor 上下文带入）。
    func featureContext(languageID: String) -> EditorFeatureRequestContext

    /// 打开位置（Quick Open / Code Action 跳转）。
    func open(_ location: EditorLocation)

    /// 应用工作区编辑（Code Action 的 edit 形态）。
    func apply(_ edit: EditorWorkspaceEdit)

    /// 应用 URI 寻址文本编辑（Code Action 的 textEdits 形态；未打开文档被忽略）。
    func applyTextEdits(_ edits: [EditorURITextEdit])
}

/// 中立 Provider → SuperEditor 贡献者的命名空间化 id（§24）。
@MainActor
enum EditorFeatureBridgeID {
    static func namespaced(pluginID: String, providerID: String) -> String {
        "\(pluginID)/\(providerID)"
    }
}

// MARK: - Completion

@MainActor
final class CompletionProviderBridge: SuperEditorCompletionContributor {
    let id: String
    private let provider: any EditorCompletionProvider
    private let bridge: any EditorFeatureHostBridge

    init(pluginID: String, provider: any EditorCompletionProvider, bridge: any EditorFeatureHostBridge) {
        self.id = EditorFeatureBridgeID.namespaced(pluginID: pluginID, providerID: provider.id)
        self.provider = provider
        self.bridge = bridge
    }

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        let request = EditorCompletionRequest(
            context: bridge.featureContext(languageID: context.languageId),
            position: EditorPosition(line: context.line, character: context.character),
            prefix: context.prefix,
            isTypeContext: context.isTypeContext
        )
        return await provider.completions(for: request).map { item in
            EditorCompletionSuggestion(
                label: item.label,
                insertText: item.insertText,
                detail: item.detail,
                priority: item.priority
            )
        }
    }
}

// MARK: - Hover

@MainActor
final class HoverProviderBridge: SuperEditorHoverContributor {
    let id: String
    private let provider: any EditorHoverProvider
    private let bridge: any EditorFeatureHostBridge

    init(pluginID: String, provider: any EditorHoverProvider, bridge: any EditorFeatureHostBridge) {
        self.id = EditorFeatureBridgeID.namespaced(pluginID: pluginID, providerID: provider.id)
        self.provider = provider
        self.bridge = bridge
    }

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        let request = EditorHoverRequest(
            context: bridge.featureContext(languageID: context.languageId),
            position: EditorPosition(line: context.line, character: context.character),
            symbol: context.symbol
        )
        return await provider.hover(for: request).map { section in
            EditorHoverSuggestion(markdown: section.markdown, priority: section.priority, dedupeKey: section.dedupeKey)
        }
    }
}

// MARK: - Code Action

@MainActor
final class CodeActionProviderBridge: SuperEditorCodeActionContributor {
    let id: String
    private let provider: any EditorCodeActionProvider
    private let bridge: any EditorFeatureHostBridge

    init(pluginID: String, provider: any EditorCodeActionProvider, bridge: any EditorFeatureHostBridge) {
        self.id = EditorFeatureBridgeID.namespaced(pluginID: pluginID, providerID: provider.id)
        self.provider = provider
        self.bridge = bridge
    }

    func provideCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        let position = EditorPosition(line: context.line, character: context.character)
        let request = EditorCodeActionRequest(
            context: bridge.featureContext(languageID: context.languageId),
            position: position,
            range: EditorV2Range(at: position),
            selectedText: context.selectedText
        )
        return await provider.codeActions(for: request).map { item in
            let bridge = self.bridge
            if let edit = item.edit {
                // edit 形态：执行时通过宿主 apply（编辑闭环与 Agent 共用，§16）。
                return EditorCodeActionSuggestion(
                    id: item.id,
                    title: item.title,
                    command: item.id,
                    priority: item.priority
                ).withExecution { bridge.apply(edit) }
            }
            if !item.textEdits.isEmpty {
                // textEdits 形态：URI 寻址，宿主解析为已打开文档后应用。
                let edits = item.textEdits
                return EditorCodeActionSuggestion(
                    id: item.id,
                    title: item.title,
                    command: item.id,
                    priority: item.priority
                ).withExecution { bridge.applyTextEdits(edits) }
            }
            return EditorCodeActionSuggestion(
                id: item.id,
                title: item.title,
                command: item.commandID ?? item.id,
                priority: item.priority
            )
        }
    }
}

// MARK: - Quick Open

@MainActor
final class QuickOpenProviderBridge: SuperEditorQuickOpenContributor {
    let id: String
    private let provider: any EditorQuickOpenProvider
    private let bridge: any EditorFeatureHostBridge

    init(pluginID: String, provider: any EditorQuickOpenProvider, bridge: any EditorFeatureHostBridge) {
        self.id = EditorFeatureBridgeID.namespaced(pluginID: pluginID, providerID: provider.id)
        self.provider = provider
        self.bridge = bridge
    }

    func provideQuickOpenItems(query: String, state: EditorState) async -> [EditorQuickOpenItemSuggestion] {
        let languageID = state.detectedLanguage?.lspLanguageId ?? state.detectedLanguage?.languageId ?? ""
        let request = EditorQuickOpenRequest(
            query: query,
            context: bridge.featureContext(languageID: languageID)
        )
        return await provider.quickOpenItems(for: request).map { item in
            let bridge = self.bridge
            return EditorQuickOpenItemSuggestion(
                id: item.id,
                sectionTitle: "",
                title: item.title,
                subtitle: item.subtitle,
                systemImage: item.systemImage,
                badge: item.badge,
                order: item.priorityPlaceholder,
                isEnabled: true
            ) {
                guard let location = item.location else { return }
                bridge.open(location)
            }
        }
    }
}

private extension EditorQuickOpenItem {
    /// SuperEditor Quick Open 无 provider 级排序输入时的中性权重。
    var priorityPlaceholder: Int { 0 }
}

// MARK: - 执行回调扩展
//
// `EditorCodeActionSuggestion` 目前是纯值（id/title/command）；
// edit 形态的动作经伴生执行表路由，避免把闭包塞进值类型破坏 Sendable。

@MainActor
private final class CodeActionExecutionTable {
    static let shared = CodeActionExecutionTable()
    private var handlers: [String: () -> Void] = [:]

    func register(id: String, handler: @escaping () -> Void) {
        handlers[id] = handler
    }

    func perform(id: String) {
        handlers[id]?()
    }
}

private extension EditorCodeActionSuggestion {
    @MainActor
    func withExecution(_ handler: @escaping () -> Void) -> EditorCodeActionSuggestion {
        CodeActionExecutionTable.shared.register(id: id, handler: handler)
        return self
    }
}
