import Foundation

/// LLM 网络请求能力协议（KitLLM 自定义，零外部依赖）。
///
/// 供应商通过此协议发起 HTTP 请求，具体实现由宿主注入（如 kernel 的 NetworkProviding 适配器）。
/// 若未注入，VendorAPIService 回退到 URLSession。
///
/// 协议使用 Foundation 标准类型（URLRequest / Data / URLResponse），
/// 避免 KitLLM 依赖任何外部包。
public protocol LLMNetworkProviding: AnyObject, Sendable {
    /// 发送非流式请求，返回响应数据和 URLResponse。
    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse)

    /// 发送流式请求，逐事件回调原始 Data。
    /// - Parameters:
    ///   - request: 已配置 URL / Header 的请求（body 由调用方写入）。
    ///   - body: 请求体数据。
    ///   - onEvent: 每个 SSE 事件块的原始 Data；返回 false 可提前终止读取。
    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws
}
