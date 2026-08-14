import Foundation



public protocol LumiLLMProvider: Sendable {
    static var info: LumiLLMProviderInfo { get }
    /// Runtime metadata. Built-in providers inherit this from their static info;
    /// user-created providers override it with their persisted configuration.
    var providerInfo: LumiLLMProviderInfo { get }
    func lumiResolveAPIKey() throws -> String
    func hasApiKey() -> Bool
    func getApiKey() -> String
    func setApiKey(_ apiKey: String)
    func removeApiKey()
    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage
    func sendStreaming(_ request: LumiLLMRequest, onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void) async throws -> LumiChatMessage
    func checkAvailability(model: String) async -> LumiModelAvailabilityResult
    func providerStatus() -> LumiLLMProviderStatus?
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition
    func errorRenderKind(for error: Error) -> String?
    func makeErrorMessage(conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage
}

/// A non-secret diagnostic for the provider's API key storage.
public enum LumiLLMProviderAPIKeyDiagnostic: Sendable, Equatable {
    case configured
    case missing
    case inaccessible(String)
}

public enum LumiLLMProviderAPIKeySaveError: LocalizedError, Sendable, Equatable {
    case empty
    case verificationFailed(provider: String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "API Key cannot be empty"
        case .verificationFailed(let provider):
            return "\(provider) API Key could not be verified after saving"
        }
    }
}

public extension LumiLLMProvider {
    var providerInfo: LumiLLMProviderInfo { Self.info }
    /// Saves and verifies the exact value through the provider's request-time
    /// resolver. This catches write failures hidden by legacy void setters.
    func saveAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LumiLLMProviderAPIKeySaveError.empty
        }

        setApiKey(trimmed)
        let persisted = try lumiResolveAPIKey()
        guard persisted == trimmed else {
            throw LumiLLMProviderAPIKeySaveError.verificationFailed(
                provider: type(of: self).info.displayName
            )
        }
    }

    /// Re-reads the key using the same path used by an actual request.
    /// This is intentionally not based on `getApiKey()`, which may collapse
    /// Keychain read failures into an empty string.
    func apiKeyDiagnostic() -> LumiLLMProviderAPIKeyDiagnostic {
        do {
            _ = try lumiResolveAPIKey()
            return .configured
        } catch let error as LumiLLMProviderSupportError {
            switch error {
            case .missingAPIKey:
                return .missing
            case .apiKeyAccessFailed(_, let details):
                return .inaccessible(details)
            default:
                return .inaccessible(error.localizedDescription)
            }
        } catch {
            return .inaccessible(error.localizedDescription)
        }
    }
}
