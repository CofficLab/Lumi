import Foundation
import ProviderEditor

final class BuiltInGrammarProvider: LanguageGrammarProviding {
    let grammarId: String
    private let languagePointer: () -> OpaquePointer?

    init(grammarId: String, languagePointer: @escaping () -> OpaquePointer?) {
        self.grammarId = grammarId
        self.languagePointer = languagePointer
    }

    func treeSitterLanguage() -> OpaquePointer? { languagePointer() }

    func highlightQueryURLs() -> [URL] {
        resourceURL(named: "highlights").map { [$0] } ?? []
    }

    func injectionQueryURL() -> URL? { resourceURL(named: "injections") }
    func localsQueryURL() -> URL? { resourceURL(named: "locals") }
    func foldsQueryURL() -> URL? { resourceURL(named: "folds") }

    private func resourceURL(named name: String) -> URL? {
        Bundle.module.url(
            forResource: name,
            withExtension: "scm",
            subdirectory: "Resources/tree-sitter-\(grammarId)"
        )
    }
}
