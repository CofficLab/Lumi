import Foundation

public struct LumiLLMRequest: Sendable {
    public let messages: [LumiChatMessage]
    public let model: String
    public let tools: [any LumiAgentTool]
    public let imageAttachments: [LumiImageAttachment]
    public let fileAttachments: [LumiFileAttachment]
    public let generationOptions: LumiLLMGenerationOptions

    public init(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool] = [],
        imageAttachments: [LumiImageAttachment] = [],
        fileAttachments: [LumiFileAttachment] = [],
        generationOptions: LumiLLMGenerationOptions = LumiLLMGenerationOptions()
    ) {
        self.messages = messages
        self.model = model
        self.tools = tools
        self.imageAttachments = imageAttachments
        self.fileAttachments = fileAttachments
        self.generationOptions = generationOptions
    }
}

public protocol LumiLLMProvider: Sendable {
    static var info: LumiLLMProviderInfo { get }
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

public extension LumiLLMProvider {
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
