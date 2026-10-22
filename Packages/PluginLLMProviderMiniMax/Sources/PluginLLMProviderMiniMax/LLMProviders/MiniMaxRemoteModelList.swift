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
    ///
    /// 上游只返回 `id / object / created / owned_by`，**不含**上下文窗口与
    /// 视觉能力（实测国内站与 Anthropic 兼容端点均如此）。因此解析时按模型
    /// 家族补全这两项，让远程新增的模型不会退化成 `LLMContextBudget` 的
    /// 32K 兜底预算。
    static func parse(data: Data) throws -> [LLMModelInfo] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VendorAPIError.decodingFailed("JSON 解析失败")
        }
        guard let entries = object["data"] as? [[String: Any]], !entries.isEmpty else {
            throw VendorAPIError.decodingFailed("缺少 data 字段或为空")
        }

        return entries.compactMap { entry in
            guard let id = entry["id"] as? String, !id.isEmpty else { return nil }
            // 上游不返回上下文窗口与能力信息，按家族规则补齐。
            return MiniMaxModelFamily.enriched(id)
        }
    }

    // MARK: - 合并

    /// 合并静态清单与远程模型。
    ///
    /// 与 CommandCode 的策略**相反**：同 id 以静态清单为准，远程不参与覆盖。
    /// 静态清单是人工核对的权威值（上下文窗口、视觉能力），远程只是模型
    /// **存在性**的来源；即使远程按家族补全了元数据，也不覆盖静态值，避免
    /// 家族规则变更时静默改写已核对的清单。
    ///
    /// - 远程新增的 id 追加在静态清单之后；
    /// - 远程新增模型若尚未带元数据，在此按家族补全——`merge` 是唯一入口，
    ///   不能依赖调用方一定走 `parse`；
    /// - **清单有但远程缺席**的模型会被标记 `isRetired`：上游已下线，但清单
    ///   仍保留它作为离线兜底底座，UI 据此做视觉区分（不隐藏）；
    /// - 远程返回为空时等价于返回静态清单，且**不标记任何退役**——此时没有
    ///   任何上游信息，标记会把全部模型误判为已下线。
    static func merge(base: [LLMModelInfo], remote: [LLMModelInfo]) -> [LLMModelInfo] {
        guard !remote.isEmpty else { return base }

        let remoteIDs = Set(remote.map(\.id))
        // 清单模型缺席于远程列表 → 上游已下线，标记退役（保留在列表中作为
        // 离线兜底底座，UI 据此做视觉区分）。
        var merged = base.map { model in
            remoteIDs.contains(model.id) ? model : Self.markingRetired(model)
        }

        let seen = Set(base.map(\.id))
        for model in remote where !seen.contains(model.id) {
            merged.append(Self.enriching(model))
        }
        return merged
    }

    /// 为缺失元数据的模型补上家族推断值。
    ///
    /// 已有上下文窗口时保持原值（远程解析已补全过），仅在缺失时按家族推断。
    private static func enriching(_ model: LLMModelInfo) -> LLMModelInfo {
        guard model.contextWindowSize == nil else { return model }
        let family = MiniMaxModelFamily.family(for: model.id)
        return LLMModelInfo(
            id: model.id,
            displayName: model.displayName,
            contextWindowSize: family.contextWindowSize,
            supportsStreaming: model.supportsStreaming,
            supportsVision: model.supportsVision || family.supportsVision,
            supportsTools: model.supportsTools
        )
    }

    /// 把模型标记为「上游已不再提供」。
    private static func markingRetired(_ model: LLMModelInfo) -> LLMModelInfo {
        LLMModelInfo(
            id: model.id,
            displayName: model.displayName,
            contextWindowSize: model.contextWindowSize,
            supportsStreaming: model.supportsStreaming,
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            isRetired: true
        )
    }
}