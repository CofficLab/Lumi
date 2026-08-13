import Foundation
import LLMKit
import KernelLumi

enum XiaomiErrorHandling {
    static func renderKind(for error: Error) -> String {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return XiaomiRenderKind.apiKeyMissing
        }

        if let statusCode = LumiProviderHTTPErrorParsing.statusCode(from: error) {
            return XiaomiRenderKind.http(statusCode)
        }

        return XiaomiRenderKind.requestFailed
    }
}
