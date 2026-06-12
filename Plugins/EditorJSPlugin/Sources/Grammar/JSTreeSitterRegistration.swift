import Foundation
import LumiCoreKit

public struct JSTreeSitterRegistration: Sendable {
    public struct LanguageDef: Sendable {
        public let languageId: String
        public let extensions: Set<String>
        public let displayName: String
        public let embeddedLanguages: Set<String>
    }

    public static let javascript = LanguageDef(
        languageId: "javascript",
        extensions: ["js", "jsx", "mjs", "cjs"],
        displayName: LumiPluginLocalization.string("JavaScript", bundle: .module),
        embeddedLanguages: ["html", "css", "json"]
    )

    public static let typescript = LanguageDef(
        languageId: "typescript",
        extensions: ["ts", "tsx", "mts", "cts"],
        displayName: LumiPluginLocalization.string("TypeScript", bundle: .module),
        embeddedLanguages: ["javascript", "jsx", "json"]
    )

    public static var registrationInfo: [[String: Any]] {
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
