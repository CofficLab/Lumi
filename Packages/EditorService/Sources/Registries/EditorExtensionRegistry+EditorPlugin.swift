import Foundation
import LumiKernel
import EditorLanguageRuntime
import EditorSource

// MARK: - Kernel → EditorService 协议适配

/// 将内核侧的 `LanguageGrammarProviding` 适配为编辑器内部要求的
/// `EditorLanguageRuntime.LanguageGrammarProviding`，桥接两个模块中同名的协议身份。
private final class KernelGrammarProviderAdapter: EditorLanguageRuntime.LanguageGrammarProviding {
    let base: any KernelLanguageGrammarProviding

    init(_ base: any KernelLanguageGrammarProviding) {
        self.base = base
    }

    var grammarId: String { base.grammarId }
    func treeSitterLanguage() -> OpaquePointer? { base.treeSitterLanguage() }
    func highlightQueryURLs() -> [URL] { base.highlightQueryURLs() }
    func injectionQueryURL() -> URL? { base.injectionQueryURL() }
    func localsQueryURL() -> URL? { base.localsQueryURL() }
    func foldsQueryURL() -> URL? { base.foldsQueryURL() }
}

extension KernelGrammarProviderAdapter: SuperEditorLanguageGrammarProvider {}

/// 将内核侧的 `EditorHighlightContributor` 适配为编辑器内部要求的具体贡献协议。
///
/// 插件的高亮 provider 实体同时遵循内核标记协议 `EditorHighlightProvider` 与
/// `EditorSource.HighlightProviding`；此处将前者向下转型还原为后者以接入高亮管线。
private final class KernelHighlightContributorAdapter: SuperEditorHighlightProviderContributor {
    let base: any EditorHighlightContributor

    init(_ base: any EditorHighlightContributor) {
        self.base = base
    }

    var id: String { base.id }

    func supports(languageId: String) -> Bool { base.supports(languageId: languageId) }

    func provideHighlightProviders(languageId: String) -> [any HighlightProviding] {
        base.highlightProviders(for: languageId).compactMap { $0 as? any HighlightProviding }
    }
}

// MARK: - Editor Extension Registrar (Kernel Contract)

extension EditorExtensionRegistry: EditorExtensionRegistrar {
    /// 桥接内核侧的 `EditorLanguageDescriptor` 到编辑器内部使用的同名类型。
    public func registerLanguage(_ descriptor: KernelEditorLanguageDescriptor) {
        let converted = EditorLanguageRuntime.EditorLanguageDescriptor(
            languageId: descriptor.languageId,
            displayName: descriptor.displayName,
            fileExtensions: descriptor.fileExtensions,
            shebangAliases: descriptor.shebangAliases,
            additionalModelineIds: descriptor.additionalModelineIds,
            lineComment: descriptor.lineComment,
            rangeCommentOpen: descriptor.rangeCommentOpen,
            rangeCommentClose: descriptor.rangeCommentClose,
            highlightLanguageId: descriptor.highlightLanguageId,
            lspLanguageId: descriptor.lspLanguageId,
            parentHighlightLanguageId: descriptor.parentHighlightLanguageId,
            additionalHighlightStems: descriptor.additionalHighlightStems
        )
        registerLanguage(converted)
    }

    /// 桥接内核侧的 `LanguageGrammarProviding` 到编辑器内部要求的具体贡献协议。
    public func registerGrammarProvider(_ provider: any KernelLanguageGrammarProviding) {
        registerGrammarProvider(KernelGrammarProviderAdapter(provider))
    }

    /// 桥接内核侧的 `EditorHighlightContributor` 到编辑器内部要求的具体贡献协议，
    /// 接入已有的插件高亮管线（`highlightProviders(for:)` 会按语言聚合这些贡献者）。
    public func registerHighlightContributor(_ contributor: any EditorHighlightContributor) {
        registerHighlightProviderContributor(KernelHighlightContributorAdapter(contributor))
    }
}
