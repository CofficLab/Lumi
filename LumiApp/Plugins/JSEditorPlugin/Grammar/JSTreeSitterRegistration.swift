import Foundation

struct JSTreeSitterRegistration: Sendable {
    struct LanguageDef: Sendable {
        let languageId: String
        let extensions: Set<String>
        let displayName: String
        let embeddedLanguages: Set<String>
    }

    static let javascript = LanguageDef(
        languageId: "javascript",
        extensions: ["js", "jsx", "mjs", "cjs"],
        displayName: "JavaScript",
        embeddedLanguages: ["html", "css", "json"]
    )

    static let typescript = LanguageDef(
        languageId: "typescript",
        extensions: ["ts", "tsx", "mts", "cts"],
        displayName: "TypeScript",
        embeddedLanguages: ["javascript", "jsx", "json"]
    )

    static var registrationInfo: [[String: Any]] {
        [javascript, typescript].map {
            [
                "languageId": $0.languageId,
                "extensions": Array($0.extensions).sorted(),
                "displayName": $0.displayName,
                "embeddedLanguages": Array($0.embeddedLanguages).sorted(),
            ]
        }
    }
}
