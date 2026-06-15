import Foundation
import SwiftTreeSitter

/// Grammar provider protocol — implemented by language plugins.
public protocol LanguageGrammarProviding: AnyObject {
    var grammarId: String { get }
    func treeSitterLanguage() -> OpaquePointer?
    func highlightQueryURLs() -> [URL]
    func injectionQueryURL() -> URL?
    func localsQueryURL() -> URL?
    func foldsQueryURL() -> URL?
}

public extension LanguageGrammarProviding {
    func injectionQueryURL() -> URL? { nil }
    func localsQueryURL() -> URL? { nil }
    func foldsQueryURL() -> URL? { nil }
}

/// Reusable grammar provider that loads tree-sitter queries from a plugin resource bundle.
open class BundledGrammarProvider: LanguageGrammarProviding {
    public let grammarId: String
    private let bundle: Bundle
    private let grammarFolderName: String
    private let languagePointer: () -> OpaquePointer?
    private let additionalHighlightStems: Set<String>
    private let parentProvider: (any LanguageGrammarProviding)?

    public init(
        grammarId: String,
        bundle: Bundle,
        grammarFolderName: String? = nil,
        languagePointer: @escaping () -> OpaquePointer?,
        additionalHighlightStems: Set<String> = [],
        parentProvider: (any LanguageGrammarProviding)? = nil
    ) {
        self.grammarId = grammarId
        self.bundle = bundle
        self.grammarFolderName = grammarFolderName ?? "tree-sitter-\(grammarId)"
        self.languagePointer = languagePointer
        self.additionalHighlightStems = additionalHighlightStems
        self.parentProvider = parentProvider
    }

    open func treeSitterLanguage() -> OpaquePointer? {
        languagePointer()
    }

    open func highlightQueryURLs() -> [URL] {
        LanguageResourceLocator.highlightURLs(
            in: bundle,
            grammarFolderName: grammarFolderName,
            additionalStems: additionalHighlightStems
        )
    }

    open func injectionQueryURL() -> URL? {
        LanguageResourceLocator.resourceURL(in: bundle, grammarFolderName: grammarFolderName, fileName: "injections.scm")
    }

    open func localsQueryURL() -> URL? {
        LanguageResourceLocator.resourceURL(in: bundle, grammarFolderName: grammarFolderName, fileName: "locals.scm")
    }

    open func foldsQueryURL() -> URL? {
        LanguageResourceLocator.resourceURL(in: bundle, grammarFolderName: grammarFolderName, fileName: "folds.scm")
    }

    public func swiftTreeSitterLanguage() -> Language? {
        guard let pointer = treeSitterLanguage() else { return nil }
        return Language(language: pointer)
    }

    public func cachedQuery() -> Query? {
        let parentURLs = parentProvider?.highlightQueryURLs() ?? []
        return LanguageQueryRegistry.shared.query(
            for: grammarId,
            highlightURLs: highlightQueryURLs(),
            parentHighlightURLs: parentURLs,
            language: swiftTreeSitterLanguage()
        )
    }
}
