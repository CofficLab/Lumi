import EditorService
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

final class EditorSwiftGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "swift",
            bundle: .module,
            languagePointer: { tree_sitter_swift() }
        )
    }
}

enum SwiftLSPConfig {
    static func resolveSourceKitLSPPath() -> String? {
        Shell.findCommandSync("sourcekit-lsp")
    }
}
