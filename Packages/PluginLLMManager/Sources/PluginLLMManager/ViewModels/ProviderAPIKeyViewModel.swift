import Combine
import Foundation
import KitLLM
import ProviderMessage

/// API Key 消息卡片（缺失 / Keychain 读取失败）唯一的数据来源与交互入口。
///
/// 供应商解析、Key 读写、重检与错误状态全部收敛到这里；View 不再直接持有
/// `LLMManaging` 或任何 `SuperLLMProvider`。
@MainActor
final class ProviderAPIKeyViewModel: ObservableObject {
    @Published var apiKey = ""
    @Published private(set) var keyIsReadable = false
    @Published private(set) var saveError: String?
    @Published private(set) var didSaveAPIKey = false
    @Published private(set) var isChecking = false
    @Published private(set) var providerAvailable = false
    @Published private(set) var providerName = "LLM Provider"
    @Published private(set) var providerWebsiteURL: URL?

    let details: String

    private let capability: any LLMManagerCapability
    private let message: Message

    init(capability: any LLMManagerCapability, message: Message) {
        self.capability = capability
        self.message = message
        self.details = Self.resolveDetails(message: message)
        reloadProviderInfo()
        reloadKeyState()
    }

    // MARK: - 用户意图

    func saveAPIKey() {
        guard let provider = resolvedProvider else { return }
        provider.setApiKey(apiKey)
        apiKey = provider.getApiKey()
        keyIsReadable = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveError = nil
        didSaveAPIKey = true
    }

    func recheckKeychain() {
        guard let provider = resolvedProvider, !isChecking else { return }
        isChecking = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.keyIsReadable = provider.hasApiKey()
            self.apiKey = provider.getApiKey()
            self.isChecking = false
        }
    }

    /// 重新从能力层解析供应商信息与 Key 状态。
    func reload() {
        reloadProviderInfo()
        reloadKeyState()
    }

    // MARK: - Private

    private var resolvedProvider: (any SuperLLMProvider)? {
        // 错误消息通常不带 providerID(AgentLoop.appendError 未填),用当前选中兜底,
        // 否则 provider == nil 会把输入框 disabled,表现为"点不进去"。
        let providerID = message.providerID ?? capability.selectedProviderID
        guard let providerID else { return nil }
        return capability.provider(id: providerID)
    }

    private func reloadProviderInfo() {
        let provider = resolvedProvider
        providerAvailable = provider != nil
        providerName = provider.map { $0.providerInfo.displayName }
            ?? message.rawErrorDetail?.replacingOccurrences(
                of: "\(LLMProviderAPIKeyMessage.rawErrorPrefix) ",
                with: ""
            )
            ?? "LLM Provider"
        providerWebsiteURL = provider?.providerInfo.websiteURL
    }

    private func reloadKeyState() {
        let value = resolvedProvider?.getApiKey() ?? ""
        apiKey = value
        keyIsReadable = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func resolveDetails(message: Message) -> String {
        let raw = message.rawErrorDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Keychain returned an unknown read error." : raw
    }
}
