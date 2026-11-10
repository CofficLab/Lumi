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
    @Published private(set) var requiresManualProviderSelection = false
    @Published private(set) var providerName = "LLM Provider"
    @Published private(set) var providerWebsiteURL: URL?

    let details: String

    private let capability: any LLMManagerCapability
    private let message: Message

    private struct ProviderBinding {
        let provider: (any SuperLLMProvider)?
        /// 旧消息文本里记录的供应商名，用于展示与反查。
        let displayNameHint: String?
        /// 旧消息没有 providerID 且无法唯一反查到供应商。
        let requiresManualSelection: Bool
    }

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
        let submitted = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try provider.setApiKeyReportingErrors(apiKey)
        } catch {
            // 存储失败时保留用户输入，不能清空错误或显示 Saved（回归 #1119）。
            didSaveAPIKey = false
            saveError = error.localizedDescription
            return
        }

        // 不抛错的旧实现可能吞掉写入失败；只有读回值与提交值一致才代表
        // Key 真正落盘，否则同样按保存失败处理（回归 #1119）。
        let stored = provider.getApiKey().trimmingCharacters(in: .whitespacesAndNewlines)
        guard stored == submitted else {
            didSaveAPIKey = false
            saveError = String(
                localized: "The API key could not be verified after saving.",
                defaultValue: "The API key could not be verified after saving."
            )
            return
        }

        apiKey = stored
        keyIsReadable = !stored.isEmpty
        saveError = nil
        didSaveAPIKey = true
    }

    func recheckKeychain() {
        guard let provider = resolvedProvider, !isChecking else { return }
        isChecking = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.apiKey = try provider.resolveAPIKey()
                self.keyIsReadable = true
            } catch {
                // Keep the last-known-good in-memory value if a recheck still
                // cannot resolve the Keychain entry; resolveAPIKey itself
                // performs the bounded full-query retry before failing.
                self.apiKey = provider.getApiKey()
                self.keyIsReadable = !self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            self.isChecking = false
        }
    }

    /// 重新从能力层解析供应商信息与 Key 状态。
    func reload() {
        reloadProviderInfo()
        reloadKeyState()
    }

    // MARK: - Private

    /// 错误消息所属的供应商。
    ///
    /// 旧版本落库的消息没有 `providerID`，只能从错误文本里的供应商名反查。
    /// 绝不能退回当前全局选中项：那会把别的供应商的 Key 读到卡片里，保存时
    /// 还会覆盖它（回归 #1120）。无法唯一确定时为 nil，由 View 禁用内联写入。
    private func resolveProvider() -> ProviderBinding {
        if let providerID = message.providerID {
            return ProviderBinding(
                provider: capability.provider(id: providerID),
                displayNameHint: nil,
                requiresManualSelection: false
            )
        }

        guard let hint = Self.providerDisplayName(in: message) else {
            return ProviderBinding(
                provider: nil,
                displayNameHint: nil,
                requiresManualSelection: true
            )
        }

        let matches = capability.allProviders().filter {
            $0.providerInfo.displayName.compare(
                hint,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
        return ProviderBinding(
            provider: matches.count == 1 ? matches[0] : nil,
            displayNameHint: hint,
            requiresManualSelection: matches.count != 1
        )
    }

    private var resolvedProvider: (any SuperLLMProvider)? {
        resolveProvider().provider
    }

    /// 从错误文本解析旧消息记录的供应商名。
    private static func providerDisplayName(in message: Message) -> String? {
        if let raw = message.rawErrorDetail?.trimmingCharacters(in: .whitespacesAndNewlines),
           raw.hasPrefix(LLMProviderAPIKeyMessage.rawErrorPrefix) {
            let name = raw
                .dropFirst(LLMProviderAPIKeyMessage.rawErrorPrefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }

        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.hasPrefix(LLMProviderAPIKeyMessage.legacyErrorPrefix) else {
            return nil
        }
        let remainder = content.dropFirst(LLMProviderAPIKeyMessage.legacyErrorPrefix.count)
        guard let closingQuote = remainder.firstIndex(of: "\"") else { return nil }
        let name = remainder[..<closingQuote].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func reloadProviderInfo() {
        let binding = resolveProvider()
        providerAvailable = binding.provider != nil
        requiresManualProviderSelection = binding.requiresManualSelection
        providerName = binding.provider?.providerInfo.displayName
            ?? binding.displayNameHint
            ?? "LLM Provider"
        providerWebsiteURL = binding.provider?.providerInfo.websiteURL
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
