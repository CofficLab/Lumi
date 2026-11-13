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

    /// Key 的读写操作。
    ///
    /// - Important: Keychain 访问走 `SecItemCopyMatching` 的**同步** IPC，
    ///   重试层还会在调用线程上 `Thread.sleep`。
    ///   在主线程上执行会占住主线程（见 issue #1286）。
    ///   因此这些操作是 `async` 的：生产实现把它们放到后台线程，
    ///   测试实现可以直接用 stub 的同步方法。
    struct KeyOperations {
        /// 读取 Key（未配置返回空串）。
        let read: @Sendable (String) async -> String
        /// 可靠解析 Key；失败时抛错。
        let resolve: @Sendable (String, String) async throws -> String
        /// 写入 Key；凭据未能落盘时抛错。
        let write: @Sendable (String, String) async throws -> Void

        /// 生产实现：把同步的 Keychain 访问放到后台线程。
        ///
        /// - Note: 直接用 `VendorAPIKeyTools` 而不是 provider 的方法，
        ///   因为 provider 是主 actor 隔离的，无法在后台线程调用
        ///   （见 issue #1286）。
        static let production = KeyOperations(
            read: { storageKey in
                await Task.detached(priority: .userInitiated) {
                    VendorAPIKeyTools.get(storageKey: storageKey)
                }.value
            },
            resolve: { storageKey, displayName in
                try await Task.detached(priority: .userInitiated) {
                    try VendorAPIKeyTools.resolve(storageKey: storageKey, displayName: displayName)
                }.value
            },
            write: { storageKey, apiKey in
                try await Task.detached(priority: .userInitiated) {
                    try VendorAPIKeyTools.setReportingErrors(apiKey, storageKey: storageKey)
                }.value
            }
        )
    }

    private let keyOperations: KeyOperations

    init(
        capability: any LLMManagerCapability,
        message: Message,
        keyOperations: KeyOperations = .production
    ) {
        self.capability = capability
        self.message = message
        self.keyOperations = keyOperations
        self.details = Self.resolveDetails(message: message)
        reloadProviderInfo()
        reloadKeyState()
    }

    // MARK: - 用户意图

    /// 保存 API Key。
    ///
    /// - Important: 写入与读回验证都是 Keychain 同步 IPC，
    ///   通过 `keyOperations` 放到后台线程执行（见 issue #1286）。
    func saveAPIKey() {
        guard let provider = resolvedProvider else { return }
        let storageKey = provider.providerInfo.apiKeyStorageKey
        let submitted = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let operations = keyOperations

        Task { @MainActor [weak self] in
            do {
                try await operations.write(storageKey, submitted)

                // 不抛错的旧实现可能吞掉写入失败；只有读回值与提交值一致才代表
                // Key 真正落盘，否则同样按保存失败处理（回归 #1119）。
                let stored = await operations.read(storageKey)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard stored == submitted else {
                    throw SaveVerificationError.mismatch
                }

                guard let self else { return }
                self.apiKey = stored
                self.keyIsReadable = !stored.isEmpty
                self.saveError = nil
                self.didSaveAPIKey = true
            } catch {
                guard let self else { return }
                // 存储失败时保留用户输入，不能清空错误或显示 Saved（回归 #1119）。
                self.didSaveAPIKey = false
                self.saveError = Self.saveErrorMessage(for: error)
            }
        }
    }

    /// 保存后读回校验失败。
    private struct SaveVerificationError: Error {
        static let mismatch = SaveVerificationError()
    }

    /// 把保存错误转成可展示的文案。
    private static func saveErrorMessage(for error: Error) -> String {
        if error is SaveVerificationError {
            return String(
                localized: "The API key could not be verified after saving.",
                defaultValue: "The API key could not be verified after saving."
            )
        }
        return error.localizedDescription
    }

    /// 重试读取 Keychain。
    ///
    /// - Important: `resolveAPIKey()` 内部会做有界重试，重试层在调用线程上
    ///   `Thread.sleep`。通过 `keyOperations` 放到后台线程执行
    ///   （见 issue #1286）。
    func recheckKeychain() {
        guard let provider = resolvedProvider, !isChecking else { return }
        let storageKey = provider.providerInfo.apiKeyStorageKey
        let displayName = provider.providerInfo.displayName
        let operations = keyOperations
        isChecking = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.apiKey = try await operations.resolve(storageKey, displayName)
                self.keyIsReadable = true
            } catch {
                // Keep the last-known-good in-memory value if a recheck still
                // cannot resolve the Keychain entry; resolveAPIKey itself
                // performs the bounded full-query retry before failing.
                self.apiKey = await operations.read(storageKey)
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

    /// 重新读取 Key 状态。
    ///
    /// - Important: 通过 `keyOperations` 在后台线程执行（见 issue #1286）。
    private func reloadKeyState() {
        guard let provider = resolvedProvider else {
            apiKey = ""
            keyIsReadable = false
            return
        }
        let storageKey = provider.providerInfo.apiKeyStorageKey
        let operations = keyOperations
        Task { @MainActor [weak self] in
            let value = await operations.read(storageKey)
            guard let self else { return }
            // - Important: 不覆盖用户已经输入的内容。
            //   读取是异步的（Keychain 同步 IPC 不能在主线程做，见 issue #1286），
            //   回来时用户可能已经在输入了；覆盖会抹掉输入（回归 #1119）。
            if self.apiKey.isEmpty {
                self.apiKey = value
            }
            self.keyIsReadable = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func resolveDetails(message: Message) -> String {
        let raw = message.rawErrorDetail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Keychain returned an unknown read error." : raw
    }
}
