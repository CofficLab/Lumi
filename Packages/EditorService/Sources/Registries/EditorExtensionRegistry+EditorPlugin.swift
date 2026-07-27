import Foundation
import LumiKernel
import EditorLanguageRuntime

// MARK: - Kernel → EditorService 协议适配

/// 将内核侧的 `LumiKernel.LanguageGrammarProviding` 适配为编辑器内部要求的
/// `EditorLanguageRuntime.LanguageGrammarProviding`，桥接两个模块中同名的协议身份。
private final class KernelGrammarProviderAdapter: EditorLanguageRuntime.LanguageGrammarProviding {
    let base: any LumiKernel.LanguageGrammarProviding

    init(_ base: any LumiKernel.LanguageGrammarProviding) {
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

// MARK: - Editor Extension Registrar (Kernel Contract)

extension EditorExtensionRegistry: EditorExtensionRegistrar {
    /// 桥接内核侧的 `EditorLanguageDescriptor` 到编辑器内部使用的同名类型。
    public func registerLanguage(_ descriptor: LumiKernel.EditorLanguageDescriptor) {
        let converted = EditorLanguageDescriptor(
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
    public func registerGrammarProvider(_ provider: any LumiKernel.LanguageGrammarProviding) {
        registerGrammarProvider(KernelGrammarProviderAdapter(provider))
    }
}
