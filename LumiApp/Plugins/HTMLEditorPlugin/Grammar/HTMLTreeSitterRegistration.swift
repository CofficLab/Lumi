import Foundation
import os

/// HTML Tree-Sitter 注册信息。
///
/// 当前编辑器内核负责实际语言注册，本类型集中声明 HTML 的语言 ID、扩展名和注入语言。
struct HTMLTreeSitterRegistration: Sendable {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.html-editor.treesitter"
    )

    struct LanguageDefinition: Sendable {
        let languageId: String = "html"
        let extensions: Set<String> = ["html", "htm", "xhtml"]
        let filenamePatterns: Set<String> = ["*.html", "*.htm", "*.xhtml"]
        let displayName: String = "HTML"
        let embeddedLanguages: Set<String> = ["css", "javascript", "typescript"]
    }

    struct InjectionQuery: Sendable {
        let language: String
        let openTag: String
        let closeTag: String
    }

    static let languageDefinition = LanguageDefinition()

    static let injectionQueries: [InjectionQuery] = [
        InjectionQuery(language: "css", openTag: "<style", closeTag: "</style>"),
        InjectionQuery(language: "javascript", openTag: "<script", closeTag: "</script>")
    ]

    static func languageId(forFileExtension fileExtension: String) -> String? {
        let normalized = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return languageDefinition.extensions.contains(normalized) ? languageDefinition.languageId : nil
    }

    static func embeddedLanguage(for region: HTMLEmbeddedRegion) -> String? {
        languageDefinition.embeddedLanguages.contains(region.language) ? region.language : nil
    }
}
