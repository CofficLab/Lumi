import Foundation
import KitLLM

/// GoatPlan 远程模型列表加载器。
///
/// 负责从 `RemoteModelSource.endpoint` 拉取模型列表并解析为 `[LLMModelInfo]`。
/// 复用 `VendorAPIService` 发起请求，自动继承重试与 HTTP 交换记录。
///
/// 当前支持 CommandCode 的响应格式（以 `{"data": [...]}` 包裹）：
/// ```json
/// {"data":[{"id":"...","name":"Claude Sonnet 5.5","context_length":1000000}]}
/// ```
///
/// 如果上游响应格式变化，直接修改 `parse(data:)` 即可。
struct RemoteModelListLoader: Sendable {

    private let apiService: VendorAPIService

    init(apiService: VendorAPIService = VendorAPIService()) {
        self.apiService = apiService
    }

    /// 拉取并解析远程模型列表。
    ///
    /// - Parameters:
    ///   - source: 远程模型源端点配置。
    ///   - apiKey: 认证用的 API Key；为空或 `nil` 时不带认证头。
    /// - Throws: `VendorAPIError`（HTTP 状态、解码失败等）。调用方决定失败
    ///   处理（保留旧缓存/静态基线），本方法**不**返回空列表掩盖错误。
    func load(from source: RemoteModelSource, apiKey: String? = nil) async throws -> [LLMModelInfo] {
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

    /// 解析 CommandCode `/models` 响应格式。
    static func parse(data: Data) throws -> [LLMModelInfo] {
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
