import Foundation

/// MLX 运行时的加载状态簿记：记录「哪个模型已成功加载、容器是否在位」。
///
/// 与容器的实际持有分离，使切换/失败的状态机可以被确定性回归测试覆盖
/// （#411），而无需构造真实的 MLX `ModelContainer`。
struct MLXModelSession {
    private(set) var loadedModelID: String?
    private(set) var hasActiveContainer: Bool

    init() {
        loadedModelID = nil
        hasActiveContainer = false
    }

    /// 容器已丢弃（unload、切换前的清理、加载失败）。丢弃后无论请求哪个
    /// 模型都必须重新加载——加载失败时尤其如此：若保留旧 ID，重选原本
    /// 可用的模型会被「ID 相同」跳过加载，直接撞上空容器守卫且无法恢复
    /// （#411）。
    mutating func discardContainer() {
        loadedModelID = nil
        hasActiveContainer = false
    }

    /// 加载成功，容器在位。
    mutating func didFinishLoad(modelID: String) {
        loadedModelID = modelID
        hasActiveContainer = true
    }

    /// 是否需要（重新）加载：请求的模型与已成功加载的模型不同。
    ///
    /// 不变量：`loadedModelID` 仅在容器在位时有意义——容器被丢弃的每条
    /// 路径（unload、切换清理、加载失败）都必须先经过 `discardContainer`，
    /// 它会把 ID 一并清空；因此 ID 相同即代表容器可用。
    func needsLoad(for modelID: String) -> Bool {
        loadedModelID != modelID
    }
}
