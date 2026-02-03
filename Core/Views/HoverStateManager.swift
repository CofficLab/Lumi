import SwiftUI
import Combine

/// 悬停状态管理器，协调多个 HoverableContainerView 的悬停状态
/// 防止多个区块的悬停事件互相干扰
@MainActor
class HoverStateManager: ObservableObject {
    static let shared = HoverStateManager()

    /// 当前活跃的悬停 ID
    @Published private(set) var activeHoverID: String?

    /// 当前悬停的 popover 是否应该保持显示
    @Published private(set) var popoverVisible: Bool = false

    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    /// 注册悬停事件
    /// - Parameters:
    ///   - id: 悬停容器的唯一标识
    ///   - isHovering: 是否悬停
    ///   - isPopover: 是否是 popover 内部
    func registerHover(id: String, isHovering: Bool, isPopover: Bool = false) {
        // 取消任何待处理的隐藏操作
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if isHovering {
            if isPopover {
                // Popover 内部悬停：只更新可见性状态
                popoverVisible = true
            } else {
                // 主内容区悬停：设置为活跃 ID
                activeHoverID = id
                popoverVisible = true
            }
        } else {
            if isPopover {
                // Popover 内部离开：不立即处理，等待主内容区的状态
                // 这里不做任何操作，让主内容区控制
            } else {
                // 主内容区离开：延迟隐藏，给用户时间移动到其他区块
                let workItem = DispatchWorkItem { [weak self] in
                    self?.activeHoverID = nil
                    self?.popoverVisible = false
                }
                hideWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            }
        }
    }

    /// 检查指定 ID 是否处于悬停状态
    func isHovering(id: String) -> Bool {
        activeHoverID == id
    }
}
