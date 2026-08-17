import Foundation
import ProviderLLMVendors
import Testing
@testable import ProviderLLMManager

/// 测试用最小供应商：按固定前缀回显，可记录收到的模型。
@MainActor
final class MockManagedProvider: ManagedLLMProvider, @preconcurrency LLMProviding {
    let providerInfo: LLMProviderInfo
    let prefix: String
    private(set) var receivedModels: [String] = []

    init(
        id: String,
        displayName: String? = nil,
        models: [String] = ["model-a"],
        defaultModel: String = "model-a",
        prefix: String = "mock"
    ) {
        self.providerInfo = LLMProviderInfo(
            id: id,
            displayName: displayName ?? id,
            defaultModel: defaultModel,
            models: models.map { LLMModelInfo(id: $0) }
        )
        self.prefix = prefix
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        receivedModels.append(request.model ?? "")
        let text = request.messages.last?.content ?? ""
        return LLMResponse(content: "\(prefix):\(text)", model: request.model)
    }
}
