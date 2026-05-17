import Foundation

public extension LumiInlinePreviewFacade {
    /// 子进程帧循环的运行策略。
    ///
    /// - `stopped`：完全不渲染，CPU 0 占用。
    /// - `idle`：低频心跳（≤1fps），保活 IOSurface 引用 + 偶尔同步状态。
    /// - `interactive`：高频（≥30fps），用户最近有输入或视图正在动。
    /// - `animating`：与 interactive 等价但语义上由动画驱动，便于未来策略细分。
    enum FrameStreamPolicy: String, Codable, Sendable, Equatable, CaseIterable {
        case stopped
        case idle
        case interactive
        case animating
    }
}
