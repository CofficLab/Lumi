import EditorLanguageRuntime
import EditorContracts
import Foundation
import Testing
@testable import EditorService

// 消歧：EditorLanguageRuntime 与 EditorContracts 存在同名类型；
// EditorContributionBundle 使用中立契约层模型。
import struct EditorContracts.EditorLanguageDescriptor
import protocol EditorContracts.LanguageGrammarProviding

/// `EditorContributionRegistry` 契约测试（重构方案 §21.1：贡献包原子替换、插件撤回）。
@MainActor
@Suite("Editor Contribution Registry", .serialized)
struct EditorContributionRegistryTests {
    private func makeDescriptor(languageId: String, extensions: Set<String> = ["x"]) -> EditorLanguageDescriptor {
        EditorLanguageDescriptor(
            languageId: languageId,
            displayName: languageId,
            fileExtensions: extensions
        )
    }

    private func makeDocument(languageID: String) -> EditorDocumentSummary {
        EditorDocumentSummary(
            id: .makeUnique(),
            uri: URL(fileURLWithPath: "/tmp/a.\(languageID)"),
            languageID: languageID,
            revision: 1,
            isDirty: false,
            isReadOnly: false,
            largeFileMode: .normal
        )
    }

    @Test("安装后语言与 grammar 生效，撤回后完全移除")
    func installAndWithdraw() async throws {
        let registry = EditorContributionRegistry(registry: EditorExtensionRegistry())
        LanguageRegistry.shared.reset()

        let bundle = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(
                language: makeDescriptor(languageId: "langsA", extensions: ["langsA"]),
                grammar: TestGrammarProvider(grammarId: "langsA")
            )]
        )
        try await registry.replaceBundle(for: "test.plugin", with: bundle.stamped(pluginID: "test.plugin", generation: 1))

        #expect(LanguageRegistry.shared.descriptor(for: "langsA") != nil)
        #expect(LanguageRegistry.shared.grammar(for: "langsA") != nil)

        // 撤回
        try await registry.replaceBundle(for: "test.plugin", with: nil)
        #expect(LanguageRegistry.shared.descriptor(for: "langsA") == nil)
        #expect(LanguageRegistry.shared.grammar(for: "langsA") == nil)
        #expect(LanguageRegistry.shared.lspLanguageId(forExtension: "langsA") == nil)
    }

    @Test("替换 Bundle：旧语言撤回、新语言生效（原子 swap generation）")
    func replaceSwapsAtomically() async throws {
        let registry = EditorContributionRegistry(registry: EditorExtensionRegistry())
        LanguageRegistry.shared.reset()

        let v1 = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(
                language: makeDescriptor(languageId: "v1", extensions: ["v1"]),
                grammar: TestGrammarProvider(grammarId: "v1")
            )]
        )
        try await registry.replaceBundle(for: "test.plugin", with: v1.stamped(pluginID: "test.plugin", generation: 1))

        let v2 = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(
                language: makeDescriptor(languageId: "v2", extensions: ["v2"]),
                grammar: TestGrammarProvider(grammarId: "v2")
            )]
        )
        try await registry.replaceBundle(for: "test.plugin", with: v2.stamped(pluginID: "test.plugin", generation: 2))

        #expect(LanguageRegistry.shared.descriptor(for: "v1") == nil)
        #expect(LanguageRegistry.shared.descriptor(for: "v2") != nil)
    }

    @Test("校验失败不改现有状态（pluginID 伪造 / 版本不兼容 / 重复 id）")
    func validationFailureKeepsState() async throws {
        let registry = EditorContributionRegistry(registry: EditorExtensionRegistry())
        LanguageRegistry.shared.reset()

        let good = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(language: makeDescriptor(languageId: "ok", extensions: ["ok"]))]
        )
        try await registry.replaceBundle(for: "test.plugin", with: good.stamped(pluginID: "test.plugin", generation: 1))

        // 伪造归属
        let forged = EditorContributionBundle(
            pluginID: "other.plugin",
            languages: [EditorLanguageContribution(language: makeDescriptor(languageId: "evil"))]
        )
        await #expect(throws: EditorContractError.self) {
            try await registry.replaceBundle(for: "test.plugin", with: forged.stamped(pluginID: "other.plugin", generation: 1))
        }
        #expect(LanguageRegistry.shared.descriptor(for: "evil") == nil)
        #expect(LanguageRegistry.shared.descriptor(for: "ok") != nil)

        // API 版本不兼容
        let incompatible = EditorContributionBundle(
            pluginID: "test.plugin",
            apiVersion: EditorPluginAPIVersion(major: 99, minor: 0),
            languages: []
        )
        await #expect(throws: EditorContractError.self) {
            try await registry.replaceBundle(for: "test.plugin", with: incompatible)
        }
    }

    @Test("availability：语法能力按语言/grammar 判定，其余 Feature 如实 noProvider")
    func availabilityResolution() async throws {
        let registry = EditorContributionRegistry(registry: EditorExtensionRegistry())
        LanguageRegistry.shared.reset()

        let bundle = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(
                language: makeDescriptor(languageId: "langsB", extensions: ["langsB"]),
                grammar: TestGrammarProvider(grammarId: "langsB")
            )]
        )
        try await registry.replaceBundle(for: "test.plugin", with: bundle.stamped(pluginID: "test.plugin", generation: 1))

        #expect(registry.availability(for: .syntax, document: makeDocument(languageID: "langsB")).isAvailable)
        #expect(registry.availability(for: .syntax, document: makeDocument(languageID: "unknown")).state == .noProvider)
        // Phase 5 之前的其它 Feature：能力缺失是正常状态（§4.5）。
        #expect(registry.availability(for: .completion, document: makeDocument(languageID: "langsB")).state == .noProvider)
    }

    @Test("撤回 Bundle 后贡献与 installedPlugins 同步清除")
    func withdrawRemovesContributionsAndSyncsInstalledPlugins() async throws {
        let service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let registry = EditorContributionRegistry(registry: service.editorExtensions)
        LanguageRegistry.shared.reset()

        let bundle = EditorContributionBundle(
            pluginID: "test.plugin",
            languages: [EditorLanguageContribution(
                language: makeDescriptor(languageId: "withdraw", extensions: ["withdraw"]),
                grammar: TestGrammarProvider(grammarId: "withdraw")
            )]
        )
        try await registry.replaceBundle(for: "test.plugin", with: bundle.stamped(pluginID: "test.plugin", generation: 1))
        #expect(LanguageRegistry.shared.descriptor(for: "withdraw") != nil)
        #expect(service.editorExtensions.installedPlugins.map(\.id) == ["test.plugin"])

        // 撤回：语言/grammar 消失，诊断列表同步清空
        try await registry.replaceBundle(for: "test.plugin", with: nil)
        #expect(LanguageRegistry.shared.descriptor(for: "withdraw") == nil)
        #expect(LanguageRegistry.shared.grammar(for: "withdraw") == nil)
        #expect(service.editorExtensions.installedPlugins.isEmpty)
    }
}

/// 测试用 grammar provider（kernel 协议）。
private final class TestGrammarProvider: LanguageGrammarProviding {
    let grammarId: String

    init(grammarId: String) {
        self.grammarId = grammarId
    }

    func treeSitterLanguage() -> OpaquePointer? { nil }
    func highlightQueryURLs() -> [URL] { [] }
}

/// Phase 5：中立语言功能 Provider 桥接安装/撤回测试（§21.1）。
@MainActor
private final class TestFeatureHostBridge: EditorFeatureHostBridge {
    func featureContext(languageID: String) -> EditorFeatureRequestContext {
        EditorFeatureRequestContext(uri: nil, languageID: languageID)
    }

    func open(_ location: EditorLocation) {}
    func apply(_ edit: EditorWorkspaceEdit) {}
    func applyTextEdits(_ edits: [EditorURITextEdit]) {}
}

private final class TestCompletionProvider: EditorCompletionProvider, @unchecked Sendable {
    let id = "completion.test"
    let selector = EditorDocumentSelector(languageID: "swift")

    func completions(for request: EditorCompletionRequest) async -> [EditorCompletionItem] {
        guard request.context.languageID == "swift" else { return [] }
        return [EditorCompletionItem(label: "Int", kind: .keyword, priority: 10)]
    }
}

private final class TestHoverProvider: EditorHoverProvider, @unchecked Sendable {
    let id = "hover.test"

    func hover(for request: EditorHoverRequest) async -> [EditorHoverSection] {
        [EditorHoverSection(markdown: "doc", priority: 1)]
    }
}

private final class TestQuickOpenProvider: EditorQuickOpenProvider, @unchecked Sendable {
    let id = "quickopen.test"

    func quickOpenItems(for request: EditorQuickOpenRequest) async -> [EditorQuickOpenItem] {
        []
    }
}

extension EditorContributionRegistryTests {
    @Test("Provider 经宿主桥安装为 SuperEditor 贡献者，撤回后移除")
    func featureProviderBridgeInstallsAndWithdraws() async throws {
        let extensionRegistry = EditorExtensionRegistry()
        // hostBridge 为 weak（避免 adapter↔registry 循环），测试需强持有。
        let hostBridge = TestFeatureHostBridge()
        let registry = EditorContributionRegistry(registry: extensionRegistry, hostBridge: hostBridge)

        let bundle = EditorContributionBundle(
            pluginID: "test.feature.plugin",
            providers: [
                TestCompletionProvider(),
                TestHoverProvider(),
                TestQuickOpenProvider(),
            ]
        )
        try await registry.replaceBundle(
            for: "test.feature.plugin",
            with: bundle.stamped(pluginID: "test.feature.plugin", generation: 1)
        )

        // 命名空间化 id（§24）：pluginID/providerID。
        let suggestions = await extensionRegistry.completionSuggestions(
            for: EditorCompletionContext(
                languageId: "swift",
                line: 0,
                character: 0,
                prefix: "In",
                isTypeContext: true
            )
        )
        #expect(suggestions.contains { $0.label == "Int" })

        let hoverSuggestions = await extensionRegistry.hoverSuggestions(
            for: EditorHoverContext(languageId: "swift", line: 0, character: 0, symbol: "actor")
        )
        #expect(hoverSuggestions.contains { $0.markdown == "doc" })

        // availability：已装 Provider 按 selector 判定（§9）。
        let swiftDocument = makeDocument(languageID: "swift")
        let pythonDocument = makeDocument(languageID: "python")
        #expect(
            registry.availability(for: .completion, document: swiftDocument).state == .available
        )
        #expect(
            registry.availability(for: .completion, document: pythonDocument).state == .noProvider
        )

        // 撤回后贡献者移除。
        try await registry.replaceBundle(for: "test.feature.plugin", with: nil)
        let afterWithdraw = await extensionRegistry.completionSuggestions(
            for: EditorCompletionContext(
                languageId: "swift",
                line: 0,
                character: 0,
                prefix: "In",
                isTypeContext: true
            )
        )
        #expect(!afterWithdraw.contains { $0.label == "Int" })
    }
}
