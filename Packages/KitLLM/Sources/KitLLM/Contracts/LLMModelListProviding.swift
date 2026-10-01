import Foundation

/// LLM 供应商「可获取模型列表」的可选能力。
///
/// 默认供应商在注册时把模型列表硬编码进 `LLMProviderInfo.models`（静态基线）。
/// 若供应商支持从远程 API 获取模型（如中转站 `GET /models`），可实现本协议，
/// 把「模型从哪来、何时刷新、失败怎么办」封装在供应商内部：
/// - `availableModels` 是动态模型池（静态基线 ∪ 远程快照，按 id 去重）
/// - 上层（`LLMManaging` / UI）只读取 `availableModels` 并监听 `modelsRefreshed`
///   事件，无需感知远程拉取细节
///
/// 本协议为可选能力，`SuperLLMProvider` 不强实现；宿主通过 `as?` 探测，
/// 未实现时回退到 `providerInfo.models` 静态逻辑，保证既有供应商零行为变化。
@MainActor
public protocol LLMModelListProviding: AnyObject, Sendable {
    /// 当前可用模型池（静态基线 + 远程快照合并，动态变化）。
    ///
    /// 实现约定：拉取失败或尚未拉取时返回「缓存优先、静态基线兜底」，
    /// **绝不**返回空列表覆盖已有模型。
    var availableModels: [LLMModelInfo] { get }

    /// 是否有远程模型源（决定是否参与定期刷新/展示同步状态）。
    /// 静态供应商返回 `false`。
    var usesRemoteModelList: Bool { get }

    /// 主动刷新模型列表。
    ///
    /// - 远程型：拉取远程模型源并更新缓存/快照；拉取失败抛错，保留旧值。
    /// - 静态型：空操作，永不抛错。
    func refreshModels() async throws

    /// 上次成功同步远程模型的时间；静态型或从未同步成功时为 `nil`。
    var lastModelSyncDate: Date? { get }
}