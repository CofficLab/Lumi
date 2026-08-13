import Foundation
import KernelLumi
import ShellKit
import TreeSitterSwift

enum EditorSwiftPluginDescriptor {
    static let swift = EditorLanguageDescriptor(
        languageId: "swift",
        displayName: "Swift",
        fileExtensions: ["swift"],
        shebangAliases: ["swift"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "swift",
        lspLanguageId: "swift"
    )
}

final class EditorSwiftGrammarProvider: LanguageGrammarProviding {
    let grammarId = "swift"

    func treeSitterLanguage() -> OpaquePointer? {
        tree_sitter_swift()
    }

    func highlightQueryURLs() -> [URL] {
        resourceURL(named: "highlights", extension: "scm").map { [$0] } ?? []
    }

    func localsQueryURL() -> URL? {
        resourceURL(named: "locals", extension: "scm")
    }

    private func resourceURL(named name: String, extension ext: String) -> URL? {
        Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources/tree-sitter-swift"
        )
    }
}

enum SwiftLSPConfig {
    static func resolveSourceKitLSPPath() -> String? {
        Shell.findCommandSync("sourcekit-lsp")
    }
}
