import Foundation
import KitLLM

/// MiniMax 远程模型列表加载器（国内站 `GET /v1/models`，OpenAI 兼容规范）。
///
/// 复用 `VendorAPIService` 发起请求，自动继承重试与 HTTP 交换记录。
/// 响应格式：
/// ```json
/// {"object":"list","data":[{"id":"MiniMax-M3","object":"model","created":1780272000,"owned_by":"minimax"}]}
/// ```
struct MiniMaxRemoteModelListLoader: Sendable {

    private let apiService: VendorAPIService

    init(apiService: VendorAPIService = VendorAPIService()) {
        self.apiService = apiService
    }

    /// 拉取并解析远程模型列表。
    ///
    /// - Parameter apiKey: Bearer 认证用的 API Key；为空时抛「未配置 API Key」。
    /// - Throws: `VendorAPIError`（缺少 Key、HTTP 状态、解析失败等）。本方法**不**
    ///   返回空列表掩盖错误，失败时调用方保留旧模型池。
    func load(apiKey: String) async throws -> [LLMModelInfo] {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VendorAPIError.missingAPIKey("MiniMax")
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")

        let data = try await apiService.send(request: request)
        let models = try Self.parse(data: data)
        guard !models.isEmpty else {
            throw VendorAPIError.decodingFailed("远程模型列表为空")
        }
        return models
    }

    // MARK: - 端点与解析

    /// 国内站模型列表端点，与 `openAIConfiguration.baseURL` 同源。
    static let endpoint = URL(string: "https://api.minimaxi.com/v1/models")!

    /// 解析 `/v1/models` 响应为模型列表。
    static func parse(data: Data) throws -> [LLMModelInfo] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VendorAPIError.decodingFailed("JSON 解析失败")
        }
        guard let entries = object["data"] as? [[String: Any]], !entries.isEmpty else {
            throw VendorAPIError.decodingFailed("缺少 data 字段或为空")
        }

        return entries.compactMap { entry in
            guard let id = entry["id"] as? String, !id.isEmpty else { return nil }
            // 上游不返回上下文窗口与能力信息，交由静态清单补齐。
            return LLMModelInfo(id: id)
        }
    }

    // MARK: - 合并

    /// 合并静态清单与远程模型。
    ///
    /// 与 CommandCode 的策略**相反**：远程响应只有模型 id，没有
    /// `contextWindowSize` / `supportsVision`，若让远程覆盖同 id 元数据，
    /// 刷一次就会把这些能力信息清空。因此：
    /// - 同 id 保留静态元数据（远程不参与覆盖）；
    /// - 远程新增的 id 追加在静态清单之后；
    /// - 远程返回为空时等价于返回静态清单。
    static func merge(base: [LLMModelInfo], remote: [LLMModelInfo]) -> [LLMModelInfo] {
        guard !remote.isEmpty else { return base }

        let baseIDs = Set(base.map(\.id))
        var seen = baseIDs
        var merged = base

        for model in remote where !seen.contains(model.id) {
            merged.append(model)
            seen.insert(model.id)
        }
        return merged
    }
}