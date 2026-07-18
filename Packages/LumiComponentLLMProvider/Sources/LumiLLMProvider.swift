import Foundation
import LumiComponentAgentTool
import LumiComponentMessage

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

    /// 解析 API Key；由具体供应商实现存储策略
    func lumiResolveAPIKey() throws -> String

    /// 是否已配置 API Key。
    func hasApiKey() -> Bool

    /// 读取当前已配置的 API Key；未配置时返回空字符串。
    func getApiKey() -> String

    /// 写入 API Key。具体存储策略由供应商自行决定（Keychain / 配置文件 / 内存等）。
    /// 协议层不规定存储方式；外部只能通过本方法写入。
    func setApiKey(_ apiKey: String)

    /// 删除 API Key。
    func removeApiKey()

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage

    /// 检查指定模型是否可用。
    /// - Parameter model: 模型名称
    /// - Returns: 模型可用性检测结果
    func checkAvailability(model: String) async -> LumiModelAvailabilityResult

    /// 供应商为模型选择器等 UI 提供的当前状态说明（如缺少 API Key、套餐过期）。
    /// 每个供应商都必须实现；无问题时返回 `nil`。
    func providerStatus() -> LumiLLMProviderStatus?

    /// 供应商对单次失败的重试决策；子类可 override。
    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition

    /// 将异常映射为错误消息的 `renderKind`；无自定义渲染时返回 `nil`。
    func errorRenderKind(for error: Error) -> String?

    /// 由调用方在重试耗尽或不可重试时，将 throw 的错误转为可展示的错误消息。
    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage
}
