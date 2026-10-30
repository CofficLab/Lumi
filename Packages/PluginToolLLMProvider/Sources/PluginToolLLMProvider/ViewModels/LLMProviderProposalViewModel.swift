import Combine
import Foundation
import KitLLM
import ProviderLLMManager

/// 供应商提案卡片的视图模型。
///
/// ## 状态归属
///
/// 提案内容（地址、协议、模型）是**用户可编辑**的草稿，保存前不落盘；
/// API Key 只存在于内存中的 `apiKey`，写入 Keychain 后即从界面状态里清空——
/// 它不会进入对话记录，也不会被回传给模型。
///
/// ## 保存时机
///
/// 保存只发生在用户点击卡片上的「添加」按钮时。工具调用本身没有任何副作用。
@MainActor
final class LLMProviderProposalViewModel: ObservableObject {

    /// 卡片状态机。
    enum Phase: Equatable {
        /// 草稿待确认。
        case editing
        /// 正在落库。
        case saving
        /// 已保存。
        case saved
        /// 保存失败。
        case failed(String)
    }

    // MARK: - 可编辑草稿

    /// 供应商标识（落库后不可改，用于 Keychain 寻址）。
    let providerID: String

    /// 展示名。
    @Published var displayName: String

    /// 备注说明。
    @Published var providerDescription: String

    /// API 根地址。
    @Published var baseURL: String

    /// 协议格式。
    @Published var apiFormat: LLMProviderAPIFormat

    /// 默认模型 id。
    @Published var defaultModel: String

    /// 模型列表。
    @Published var models: [UserDefinedCloudModel]

    /// 官网地址。
    @Published var websiteURL: String

    /// 待添加的模型 id 输入框内容。
    @Published var pendingModelID: String = ""

    /// API Key 输入框内容（仅存在于内存，保存后清空）。
    @Published var apiKey: String = ""

    /// 卡片状态。
    @Published private(set) var phase: Phase = .editing

    // MARK: - 依赖

    private let store: UserDefinedCloudProviderStore?
    private let manager: (any LLMManaging)?

    init(
        proposal: LLMProviderProposal,
        store: UserDefinedCloudProviderStore?,
        manager: (any LLMManaging)?
    ) {
        self.providerID = proposal.id
        self.displayName = proposal.displayName
        self.providerDescription = proposal.providerDescription
        self.baseURL = proposal.baseURL
        self.apiFormat = proposal.apiFormat
        self.defaultModel = proposal.defaultModel
        self.models = proposal.models
        self.websiteURL = proposal.websiteURLString ?? ""
        self.store = store
        self.manager = manager
    }

    /// 供应商是否已被保存过（决定按钮文案）。
    var isExistingProvider: Bool {
        store?.isCustomProvider(id: providerID) ?? false
    }

    /// 模型是否为空（保存前的即时校验反馈）。
    var hasValidModels: Bool {
        !models.isEmpty
    }

    // MARK: - 草稿编辑

    /// 添加一个模型。
    func addPendingModel() {
        let id = pendingModelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        guard !models.contains(where: { $0.id == id }) else {
            pendingModelID = ""
            return
        }
        models.append(UserDefinedCloudModel(id: id))
        if defaultModel.isEmpty {
            defaultModel = id
        }
        pendingModelID = ""
    }

    /// 移除一个模型。
    func removeModel(id: String) {
        models.removeAll { $0.id == id }
        if defaultModel == id {
            defaultModel = models.first?.id ?? ""
        }
    }

    // MARK: - 保存

    /// 保存提案：落盘 + 注册 + 写入 API Key。
    func save() {
        guard let store else {
            phase = .failed(Self.errorMessage("The provider service is unavailable."))
            return
        }

        let configuration = currentConfiguration()

        // 端点策略与配置规则两道闸门：任一不过都不落盘。
        do {
            _ = try ProviderEndpointPolicy.validate(baseURL: configuration.baseURL)
            _ = try configuration.validated()
        } catch let error as ProviderEndpointPolicyError {
            phase = .failed(Self.localizedMessage(for: error))
            return
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        // 同 id 已存在且不是自定义供应商时拒绝写入，避免覆盖内置实现。
        if let existing = manager?.provider(id: providerID), !(existing is UserDefinedCloudProvider) {
            let format = pluginLocalization.string("The identifier '%@' is already used by another provider.")
            phase = .failed(String(format: format, providerID))
            return
        }

        phase = .saving
        do {
            try store.upsert(configuration)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        // API Key 只写 Keychain，不进配置、不进对话。
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            manager?.provider(id: providerID)?.setApiKey(trimmedKey)
            apiKey = ""
        }

        phase = .saved
    }

    /// 把当前卡片上的供应商设为当前使用中的供应商。
    func selectAsCurrent() {
        guard let manager,
              manager.provider(id: providerID) != nil else {
            phase = .failed(Self.errorMessage("The provider is not available yet."))
            return
        }
        let model = models.contains { $0.id == defaultModel } ? defaultModel : models.first?.id
        manager.select(providerID: providerID, model: model, reason: .userSelected)
    }

    // MARK: - 构造

    /// 由当前草稿构造供应商配置。
    func currentConfiguration() -> UserDefinedCloudProviderConfiguration {
        UserDefinedCloudProviderConfiguration(
            id: providerID,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: providerDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiFormat: apiFormat,
            defaultModel: defaultModel.trimmingCharacters(in: .whitespacesAndNewlines),
            models: models,
            websiteURLString: websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 本地化错误文案。
    private static func errorMessage(_ fallback: String) -> String {
        pluginLocalization.string(fallback)
    }

    /// 端点策略拒绝原因的本地化文案。
    private static func localizedMessage(for error: ProviderEndpointPolicyError) -> String {
        switch error {
        case .invalidURL:
            return pluginLocalization.string("The endpoint is not a valid URL.")
        case .unsupportedScheme:
            return pluginLocalization.string("The endpoint scheme is not supported. Use http or https.")
        case .insecureRemoteEndpoint:
            return pluginLocalization.string("The endpoint must use https.")
        case .privateNetworkAddress:
            return pluginLocalization.string("The endpoint points to a private or local network address.")
        }
    }
}
