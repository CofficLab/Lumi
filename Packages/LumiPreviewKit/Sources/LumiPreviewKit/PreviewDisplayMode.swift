import Foundation

/// 预览显示模式。
///
/// `image` 模式使用宿主进程返回的 PNG 截图在 Lumi 中渲染预览。
/// `live` 模式通过独立宿主进程的真实 `NSHostingView/NSView` 窗口提供可交互的 Live Canvas。
public enum PreviewDisplayMode: String, Codable, Sendable, Equatable, CaseIterable {
    /// 图片模式：显示宿主进程离屏渲染的 PNG 截图。
    case image

    /// Live 模式：显示宿主进程中真实可交互的预览窗口。
    case live
}

/// Live 预览状态。
///
/// 描述 Live 模式在当前会话中的可用性和运行状态。
public enum LivePreviewState: String, Codable, Sendable, Equatable {
    /// Live 模式尚未启动或不可用。
    case unavailable

    /// Live 模式可用但尚未启动。
    case available

    /// 正在启动 Live 预览窗口。
    case launching

    /// Live 预览窗口正在运行。
    case running

    /// Live 预览启动或运行失败，已降级到图片模式。
    case failed

    /// Live 预览已被用户停止。
    case stopped
}

/// 会话的 Live 模式详细信息。
public struct LivePreviewInfo: Codable, Sendable, Equatable {
    /// Live 预览当前状态。
    public var state: LivePreviewState

    /// Live 模式不可用或失败时的原因描述。
    public var unavailableReason: String?

    /// 宿主进程中 live window 的编号（用于跨进程窗口层级协调）。
    public var hostWindowNumber: Int?

    /// 宿主进程 PID，用于诊断和清理残留进程。
    public var hostProcessID: Int32?

    /// 创建一个 Live 预览信息。
    ///
    /// - Parameters:
    ///   - state: Live 预览状态。
    ///   - unavailableReason: 不可用原因。
    ///   - hostWindowNumber: 宿主进程窗口编号。
    ///   - hostProcessID: 宿主进程 PID。
    public init(
        state: LivePreviewState = .unavailable,
        unavailableReason: String? = nil,
        hostWindowNumber: Int? = nil,
        hostProcessID: Int32? = nil
    ) {
        self.state = state
        self.unavailableReason = unavailableReason
        self.hostWindowNumber = hostWindowNumber
        self.hostProcessID = hostProcessID
    }
}
