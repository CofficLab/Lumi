import Foundation

public extension LumiPreviewFacade {
    /// 跨进程可表达的鼠标形状。
    ///
    /// 子进程在注入 mouse moved / entered 后读取当前 `NSCursor`，主进程再把同等形状应用到
    /// `PreviewSurfaceView` 的 cursor rect，避免预览画面和宿主 cursor 状态脱节。
    enum PreviewCursorShape: String, CaseIterable, Codable, Sendable, Equatable {
        case arrow
        case iBeam
        case pointingHand
        case openHand
        case closedHand
        case crosshair
        case resizeLeftRight
        case resizeUpDown
        case operationNotAllowed
        case disappearingItem
    }
}
