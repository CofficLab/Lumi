import Foundation
import LumiCoreKit
import LLMKit

enum XiaomiErrorHandling {
    static func renderKind(for error: Error) -> String {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return XiaomiRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return XiaomiRenderKind.http(statusCode)
        }

        return XiaomiRenderKind.requestFailed
    }
}
