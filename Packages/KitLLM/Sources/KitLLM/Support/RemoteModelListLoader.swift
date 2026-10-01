import Foundation

/// 远程模型列表加载器。
///
/// 负责从 `RemoteModelSource.endpoint` 拉取模型列表并解析为 `[LLMModelInfo]`。
/// 复用 `VendorAPIService` 发起请求，自动继承重试与 HTTP 交换记录。
///
/// 支持两种常见响应格式（以 `{"data": [...]}` 包裹）：
/// 1. OpenAI 标准：`{"data":[{"id":"gpt-4o","object":"model"}]}`
/// 2. CommandCode / OpenRouter 变体：
///    `{"data":[{"id":"...","name":"Claude Sonnet 5.5","context_length":1000000}]}`
///    额外提供 displayName 与 contextWindowSize。
///
/// 能力标注（supportsVision / supportsTools / supportsStreaming）远程响应通常
/// 不包含，用默认值；需要强标注的模型由调用方通过 `knownCapabilities` 按 id 叠加。
public struct RemoteModelListLoader: Sendable {
    /// 按模型 id 精确匹配的已知能力标注（叠加在默认值之上）。
    public struct CapabilityOverride: Sendable {
        public let supportsVision: Bool?
        public let supportsTools: Bool?
        public let supportsStreaming: Bool?

        public init(
            supportsVision: Bool? = nil,
            supportsTools: Bool? = nil,
            supportsStreaming: Bool? = nil
        ) {
            self.supportsVision = supportsVision
            self.supportsTools = supportsTools
            self.supportsStreaming = supportsStreaming
        }
    }

    private let apiService: VendorAPIService
    private let knownCapabilities: [String: CapabilityOverride]

    public init(
        apiService: VendorAPIService = VendorAPIService(),
        knownCapabilities: [String: CapabilityOverride] = [:]
    ) {
        self.apiService = apiService
        self.knownCapabilities = knownCapabilities
    }

    /// 拉取并解析远程模型列表。
    ///
    /// - Parameters:
    ///   - source: 远程模型源端点配置。
    ///   - apiKey: 认证用的 API Key；为空或 `nil` 时不带认证头。
    /// - Throws: `VendorAPIError`（HTTP 状态、解码失败等）。调用方决定失败
    ///   处理（保留旧缓存/静态基线），本方法**不**返回空列表掩盖错误。
    public func load(from source: RemoteModelSource, apiKey: String? = nil) async throws -> [LLMModelInfo] {
        var request = URLRequest(url: source.endpoint)
        request.httpMethod = "GET"
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let data = try await apiService.send(request: request)
        let models = try Self.parse(data: data)
        guard !models.isEmpty else {
            throw VendorAPIError.decodingFailed("远程模型列表为空")
        }
        return models
    }

    // MARK: - Parsing

    /// 解析两种常见 `{"data": [...]}` 响应格式。
    public static func parse(data: Data) throws -> [LLMModelInfo] {
        let object: [String: Any]
        do {
            object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        } catch {
            throw VendorAPIError.decodingFailed("JSON 解析失败：\(error.localizedDescription)")
        }
        guard let entries = object["data"] as? [[String: Any]], !entries.isEmpty else {
            throw VendorAPIError.decodingFailed("缺少 data 字段或为空")
        }

        var result: [LLMModelInfo] = []
        for entry in entries {
            guard let id = entry["id"] as? String, !id.isEmpty else { continue }
            let displayName = entry["name"] as? String
            let contextLength = (entry["context_length"] as? NSNumber)?.intValue
                ?? (entry["contextLength"] as? NSNumber)?.intValue
            result.append(
                LLMModelInfo(
                    id: id,
                    displayName: displayName,
                    contextWindowSize: contextLength
                )
            )
        }
        return result
    }
}