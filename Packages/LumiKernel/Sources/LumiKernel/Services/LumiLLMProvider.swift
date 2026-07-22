import Foundation

public struct LumiLLMRequest: Sendable {
    public let messages: [LumiChatMessage]
    public let model: String
    public let tools: [any LumiAgentTool]
    public let imageAttachments: [LumiImageAttachment]

    public init(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool] = [],
        imageAttachments: [LumiImageAttachment] = []
    ) {
        self.messages = messages
        self.model = model
        self.tools = tools
        self.imageAttachments = imageAttachments
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
