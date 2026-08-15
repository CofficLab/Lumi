import Foundation

// MARK: - V2 契约注册

extension KernelLumiContainer {
    /// 注册编辑器 Host Capability V2（由 `EditorHostPlugin` 调用）。
    ///
    /// **不转发 objectWillChange**：选择、文档 revision 等高频状态如果经
    /// Kernel 全局广播会在每次按键时拖慢整个 app。消费方必须直接订阅
    /// 各子能力的 `statePublisher`（CurrentValue 语义），而不是观察 Kernel
    /// 全局变化（见重构方案 §8.8）。
    public func registerEditorV2(_ editor: any EditorProvidingV2) throws {
        try registerService(EditorProvidingV2.self, editor, forwardsObjectWillChange: false)
    }
}

// MARK: - V2 服务访问器

extension KernelLumiContainer {
    /// 编辑器 Host Capability V2。
    ///
    /// 可选服务：`EditorHostPlugin` 未就绪时为 nil。
    /// 消费方应 `guard let editor = kernel.editorV2 else { … }` 优雅降级，
    /// 不假设编辑器宿主一定存在（能力缺失是正常状态）。
    public var editorV2: (any EditorProvidingV2)? {
        resolveService(EditorProvidingV2.self)
    }
}
