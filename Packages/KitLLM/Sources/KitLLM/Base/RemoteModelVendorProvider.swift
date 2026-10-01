import Foundation

/// 远程模型源供应商**便利基类**（开箱即用，完全可选）。
///
/// 继承本类的供应商只需 override `remoteModelSource` 声明端点，即可获得：
/// - `refreshModels()`：通过 `RemoteModelListLoader` 拉取远程 `/models`
///   端点（复用 `VendorAPIService` 的重试与 HTTP 交换记录）
/// - `availableModels`：静态基线 ∪ 远程快照 / 磁盘缓存，失败时缓存兜底
/// - `usesRemoteModelList` / `lastModelSyncDate`：UI 展示同步状态
///
/// **本类是可选便利，不是约束**：
/// - 不想用 loader / 缓存的供应商：直接继承 `VendorLLMProvider`，
///   自行 override `availableModels` / `refreshModels`（完全自主）。
/// - 需要自定义解析的供应商：override `parseModelList(data:)` 或
///   整个 `refreshModels()`。
///
/// 核心约定（与协议一致）：**拉取失败绝不丢模型** —— 保留旧快照 /
/// 磁盘缓存，全无时回退 `providerInfo.models` 静态基线。
@MainActor
open class RemoteModelVendorProvider: VendorLLMProvider {

    private let modelListCache: LLMModelListCache
    private var fetchedRemoteModels: [LLMModelInfo] = []
    private var remoteSyncDate: Date?

    /// 远程模型源端点；子类 override 声明。返回 `nil` 时行为退化为静态供应商。
    open var remoteModelSource: RemoteModelSource? { nil }

    public override init(info: LLMProviderInfo, apiService: VendorAPIService = VendorAPIService()) {
        self.modelListCache = LLMModelListCache(providerID: info.id)
        super.init(info: info, apiService: apiService)
    }

    // MARK: - SuperLLMProvider（远程实现）

    open override var usesRemoteModelList: Bool { remoteModelSource != nil }

    open override var lastModelSyncDate: Date? { remoteSyncDate }

    /// 动态模型池：静态基线 ∪（远程快照 → 磁盘缓存）。
    ///
    /// - 远程优先（保留远程的 displayName / contextWindowSize）
    /// - 静态基线兜底补齐（保证永不为空）
    /// - 排序：先静态声明顺序，远程新增模型追加在后
    open override var availableModels: [LLMModelInfo] {
        let base = providerInfo.models

        let remote: [LLMModelInfo]
        if usesRemoteModelList, !fetchedRemoteModels.isEmpty {
            remote = fetchedRemoteModels
        } else if usesRemoteModelList, let cached = modelListCache.cachedSnapshot() {
            remote = cached.models
        } else {
            remote = []
        }

        // 合并：远程优先覆盖同 id 元数据，静态补齐缺漏。
        var byID: [String: LLMModelInfo] = [:]
        for model in base { byID[model.id] = model }
        for model in remote { byID[model.id] = model }

        var seen = Set<String>()
        var merged: [LLMModelInfo] = []
        for model in base {
            merged.append(byID[model.id] ?? model)
            seen.insert(model.id)
        }
        for model in remote where !seen.contains(model.id) {
            merged.append(model)
            seen.insert(model.id)
        }
        return merged
    }

    /// 拉取远程模型端点并更新内部快照与缓存。
    ///
    /// - Throws: 拉取/解析失败时抛错，**保留旧模型池**（调用方无需回滚）。
    open override func refreshModels() async throws {
        guard let source = remoteModelSource else { return }
        let apiKey: String?
        if let storageKey = source.apiKeyStorageKey, !storageKey.isEmpty {
            apiKey = getApiKey()
        } else {
            apiKey = nil
        }
        let loader = RemoteModelListLoader(apiService: apiService)
        let models = try await loader.load(from: source, apiKey: apiKey)
        fetchedRemoteModels = models
        let now = Date()
        remoteSyncDate = now
        modelListCache.store(models: models, syncedAt: now)
    }
}
