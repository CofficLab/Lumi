import EditorLanguageRuntime
import Foundation
import EditorContracts
// 消歧：EditorLanguageRuntime 也有同名 EditorLanguageDescriptor。
import struct EditorContracts.EditorLanguageDescriptor

/// 编辑器贡献包注册表（`EditorExtensionHosting` 实现，重构方案 §9）。
///
/// 按**插件维度**原子安装/替换/撤回 `EditorContributionBundle`：
/// 1. 校验（API 版本兼容、内部 id 一致性）——失败抛错且不改现有状态；
/// 2. 撤回旧 generation 的贡献（语言/grammar/高亮）；
/// 3. 安装新贡献并记录明细；
/// 4. 递增并记录 generation，发布一次变化。
///
/// 不再使用全局 `reset()` 回放（§9.3）。
@MainActor
public final class EditorContributionRegistry: EditorExtensionHosting {
    /// 某插件当前已安装的贡献明细。
    private struct InstalledContribution {
        let generation: UInt64
        let languageIds: [String]
        let grammarIds: [String]
        let highlightContributorIds: [String]
        let completionProviderIds: [String]
        let hoverProviderIds: [String]
        let codeActionProviderIds: [String]
        let quickOpenProviderIds: [String]
    }

    private let registry: EditorExtensionRegistry
    /// 宿主桥（Phase 5）：中立 Provider 适配所需的活动文档上下文与执行入口。
    /// Host 在装配完 V2 Adapter 后注入（Adapter 即桥实现）。
    public weak var hostBridge: (any EditorFeatureHostBridge)?

    /// 已安装 Provider 的 selector 表（命名空间化 id → selector，availability 用）。
    private var providerSelectors: [String: EditorDocumentSelector] = [:]
    private var installed: [String: InstalledContribution] = [:]
    private var nextGeneration: UInt64 = 1

    /// 最近一次安装/撤回事件描述（调试与测试用；UI 恢复依赖 State，§8.9）。
    public private(set) var lastChangeDescription: String = ""

    public init(registry: EditorExtensionRegistry, hostBridge: (any EditorFeatureHostBridge)? = nil) {
        self.registry = registry
        self.hostBridge = hostBridge
    }

    // MARK: - EditorExtensionHosting

    public func replaceBundle(for pluginID: String, with bundle: EditorContributionBundle?) async throws {
        guard let bundle else {
            withdraw(pluginID: pluginID)
            return
        }

        // 1. 校验（失败不动现有状态）
        guard bundle.pluginID == pluginID else {
            throw EditorContractError.invalidWorkspaceEdit(
                reason: "bundle pluginID '\(bundle.pluginID)' != stamped '\(pluginID)'"
            )
        }
        guard bundle.isCompatible(with: .current) else {
            throw EditorContractError.invalidWorkspaceEdit(
                reason: "incompatible api version \(bundle.apiVersion) vs host \(EditorPluginAPIVersion.current)"
            )
        }
        let issues = bundle.validationIssues
        guard issues.isEmpty else {
            throw EditorContractError.invalidWorkspaceEdit(reason: issues.joined(separator: "; "))
        }

        // 2. 撤回旧 generation（§9.3 步骤 4：取消旧代请求/任务）
        withdraw(pluginID: pluginID)

        // 3. 安装并记录明细
        var languageIds: [String] = []
        var grammarIds: [String] = []
        var highlightContributorIds: [String] = []

        for contribution in bundle.languages {
            registry.registerLanguage(contribution.language)
            languageIds.append(contribution.language.languageId)

            if let grammar = contribution.grammar {
                registry.registerGrammarProvider(grammar)
                grammarIds.append(grammar.grammarId)
            }

            for contributor in contribution.highlightContributors {
                registry.registerHighlightContributor(contributor)
                highlightContributorIds.append(contributor.id)
            }
        }

        // 3.5 安装语言功能 Provider（Phase 5 §10；Host 桥接为 SuperEditor 贡献者）
        var completionIds: [String] = []
        var hoverIds: [String] = []
        var codeActionIds: [String] = []
        var quickOpenIds: [String] = []
        if let hostBridge {
            for provider in bundle.providers {
                let namespacedID = EditorFeatureBridgeID.namespaced(pluginID: pluginID, providerID: provider.id)
                providerSelectors[namespacedID] = provider.selector
                if let completion = provider as? any EditorCompletionProvider {
                    let bridge = CompletionProviderBridge(pluginID: pluginID, provider: completion, bridge: hostBridge)
                    registry.registerCompletionContributor(bridge)
                    completionIds.append(bridge.id)
                }
                if let hover = provider as? any EditorHoverProvider {
                    let bridge = HoverProviderBridge(pluginID: pluginID, provider: hover, bridge: hostBridge)
                    registry.registerHoverContributor(bridge)
                    hoverIds.append(bridge.id)
                }
                if let codeAction = provider as? any EditorCodeActionProvider {
                    let bridge = CodeActionProviderBridge(pluginID: pluginID, provider: codeAction, bridge: hostBridge)
                    registry.registerCodeActionContributor(bridge)
                    codeActionIds.append(bridge.id)
                }
                if let quickOpen = provider as? any EditorQuickOpenProvider {
                    let bridge = QuickOpenProviderBridge(pluginID: pluginID, provider: quickOpen, bridge: hostBridge)
                    registry.registerQuickOpenContributor(bridge)
                    quickOpenIds.append(bridge.id)
                }
            }
        }

        // 4. 记录 generation，发布一次变化
        let generation = nextGeneration
        nextGeneration += 1
        installed[pluginID] = InstalledContribution(
            generation: generation,
            languageIds: languageIds,
            grammarIds: grammarIds,
            highlightContributorIds: highlightContributorIds,
            completionProviderIds: completionIds,
            hoverProviderIds: hoverIds,
            codeActionProviderIds: codeActionIds,
            quickOpenProviderIds: quickOpenIds
        )
        lastChangeDescription = "installed \(pluginID) gen=\(generation) languages=\(languageIds)"
        syncInstalledPlugins()
    }

    public func availability(for feature: EditorFeature, document: EditorDocumentSummary) -> EditorFeatureAvailability {
        // Phase 5：语言功能 Provider 已可判定；其余 Feature（LSP 驱动）由宿主
        // 内部管线提供，此处如实返回 noProvider（能力缺失是正常状态，§4.5）。
        switch feature {
        case .syntax:
            guard let descriptor = LanguageRegistry.shared.descriptor(for: document.languageID) else {
                return EditorFeatureAvailability(.noProvider)
            }
            let hasGrammar = LanguageRegistry.shared.grammar(for: descriptor.highlightLanguageId) != nil
            return EditorFeatureAvailability(
                hasGrammar ? .available : .temporarilyUnavailable(reason: "no grammar for \(document.languageID)")
            )
        case .completion, .hover, .codeAction:
            let hasMatch = providerIDs(for: feature).contains { id in
                providerSelectors[id]?.matches(document) ?? false
            }
            return EditorFeatureAvailability(hasMatch ? .available : .noProvider)
        default:
            return EditorFeatureAvailability(.noProvider)
        }
    }

    /// 命中某能力的已安装 Provider id 列表（按贡献记录）。
    private func providerIDs(for feature: EditorFeature) -> [String] {
        switch feature {
        case .completion:
            return installed.values.flatMap(\.completionProviderIds)
        case .hover:
            return installed.values.flatMap(\.hoverProviderIds)
        case .codeAction:
            return installed.values.flatMap(\.codeActionProviderIds)
        default:
            return []
        }
    }

    // MARK: - Private

    /// 将已安装贡献的插件列表同步到 legacy 诊断 UI 使用的 installedPlugins。
    private func syncInstalledPlugins() {
        registry.recordInstalledPlugins(
            installed.keys.sorted().map {
                EditorInstalledPluginRecord(
                    id: $0,
                    displayName: $0,
                    description: "",
                    order: 0,
                    isConfigurable: false
                )
            }
        )
    }

    private func withdraw(pluginID: String) {
        guard let contribution = installed.removeValue(forKey: pluginID) else {
            return
        }
        for languageId in contribution.languageIds {
            LanguageRegistry.shared.unregister(languageId: languageId)
        }
        for grammarId in contribution.grammarIds {
            LanguageRegistry.shared.unregisterGrammarProvider(grammarId: grammarId)
        }
        for contributorId in contribution.highlightContributorIds {
            registry.unregisterHighlightProviderContributor(id: contributorId)
        }
        for providerId in contribution.completionProviderIds {
            registry.unregisterCompletionContributor(id: providerId)
        }
        for providerId in contribution.hoverProviderIds {
            registry.unregisterHoverContributor(id: providerId)
        }
        for providerId in contribution.codeActionProviderIds {
            registry.unregisterCodeActionContributor(id: providerId)
        }
        for providerId in contribution.quickOpenProviderIds {
            registry.unregisterQuickOpenContributor(id: providerId)
        }
        for providerId in contribution.completionProviderIds
            + contribution.hoverProviderIds
            + contribution.codeActionProviderIds
            + contribution.quickOpenProviderIds {
            providerSelectors.removeValue(forKey: providerId)
        }
        lastChangeDescription = "withdrew \(pluginID) gen=\(contribution.generation)"
        syncInstalledPlugins()
    }
}
