import SwiftUI
import Combine

/// 悬停状态管理器，协调多个 HoverableContainerView 的悬停状态
/// 防止多个区块的悬停事件互相干扰
@MainActor
class HoverStateManager: ObservableObject {
    static let shared = HoverStateManager()

    /// 当前活跃的悬停 ID
    @Published private(set) var activeHoverID: String? {
        didSet {
            if Self.verbose {
                print("[HoverStateManager] activeHoverID changed: \(oldValue?.description ?? "nil") -> \(activeHoverID?.description ?? "nil")")
            }
        }
    }

    /// 当前悬停的 popover 是否应该保持显示
    @Published private(set) var popoverVisible: Bool = false

    private var hideWorkItem: DispatchWorkItem?
    static let verbose = true

    private init() {
        if Self.verbose {
            print("[HoverStateManager] Initialized")
        }
    }

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
            // 鼠标进入：设置活跃 ID
            if activeHoverID != id {
                if Self.verbose {
                    print("[HoverStateManager] Mouse entered \(id), setting as active")
                }
                activeHoverID = id
            }
            popoverVisible = true
        } else {
            // 鼠标离开
            if isPopover {
                // Popover 内部离开：不做处理，因为主内容区可能还在 hover
                if Self.verbose {
                    print("[HoverStateManager] Mouse left popover of \(id), ignoring")
                }
            } else {
                // 主内容区离开：延迟隐藏，给用户时间移动到 popover
                if Self.verbose {
                    print("[HoverStateManager] Mouse left main content of \(id), scheduling hide in 0.3s")
                }

                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    // 只有当没有其他区块活跃时才隐藏
                    if self.activeHoverID == id {
                        if Self.verbose {
                            print("[HoverStateManager] Hiding \(id)")
                        }
                        self.activeHoverID = nil
                        self.popoverVisible = false
                    }
                }
                hideWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
            }
        }
    }

    /// 检查指定 ID 是否处于悬停状态
    func isHovering(id: String) -> Bool {
        let result = activeHoverID == id
        if Self.verbose {
            print("[HoverStateManager] Checking hover for \(id): \(result)")
        }
        return result
    }
}
