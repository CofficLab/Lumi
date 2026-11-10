import SwiftUI

/// 消息行 hover 的**进入防抖**状态容器。
///
/// - Important: hover 的**进入**必须有防抖。
///   列表滚动时光标下的行快速进出，若立即物化操作按钮就会造成
///   「hover 风暴」：按钮反复出现 / 消失，视觉上非常突兀。
///   离开则**立即**隐藏（标准菜单式交互）。
///
/// - Note: 基准是 V1–V3 的 `MessageViewChrome`，它早就有同样的 150ms 策略；
///   V4 之前没有防抖，是「hover 突兀感」的来源之一。
///
/// - Important: 本类型**只**负责「是否 hover」这一个事实，
///   不决定任何视觉表现。显隐策略由各渲染器自己决定。
@MainActor
public final class MessageHoverState: ObservableObject {

    /// 进入延迟（秒）。
    ///
    /// - Note: 150ms 是标准菜单式交互的量级 —— 短到感觉即时，
    ///   长到足以过滤掉滚动时的掠过。
    public static let enterDelay: TimeInterval = 0.15

    /// 当前是否处于 hover 状态。
    @Published public private(set) var isHovered = false

    /// 进入防抖任务。
    private var debounceTask: Task<Void, Never>?

    public init() {}

    /// 设置 hover 状态。
    ///
    /// - Parameter isHovering: 指针是否在本区域内。
    public func setHovering(_ isHovering: Bool) {
        if isHovering {
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(Self.enterDelay * 1000)))
                guard !Task.isCancelled else { return }
                isHovered = true
            }
        } else {
            debounceTask?.cancel()
            debounceTask = nil
            isHovered = false
        }
    }
}
