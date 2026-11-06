import AppKit
import ApplicationServices
import Foundation

/// 辅助功能（TCC Accessibility）权限的检测与引导。
///
/// ## 为什么需要独立的服务
///
/// `AXIsProcessTrustedWithOptions(prompt: true)` 的系统弹窗有两个坑：
///
/// 1. **只在应用「尚未被用户拒绝」时才会出现**。一旦用户点过「拒绝」，
///    系统就不再弹窗，调用直接返回 `false`。此时按钮的唯一效果就是
///    「什么都没发生」——用户完全无从判断下一步该做什么。
/// 2. **弹窗异步触发，不影响返回值**。调用返回时授权可能仍未完成，
///    也没法据此判断用户到底点了哪个按钮。
///
/// macOS 没有提供「用户是否已拒绝过」的查询接口，因此本服务不去猜测
/// 拒绝状态，而是把**两条独立的出口**都交给调用方：
///
/// - `requestPermission()`：触发系统弹窗（用户尚未拒绝时有效）；
/// - `openAccessibilitySettings()`：总是跳到系统设置面板手动开启。
///
/// 设置页同时提供这两个入口，用户无论走到哪一步都有事可做、看得见结果。
///
/// 同样的边界在 `ComputerUsePermissionService` 里也有一份实现；
/// 两者分属不同插件包，无法直接共享，故此处保持独立但语义一致。
enum TextActionsPermissionService {

    // MARK: - 状态

    /// 辅助功能授权状态。
    enum Status: Equatable {
        /// 已授权：可以读取其他应用的选区。
        case granted
        /// 未授权：系统仍会弹窗提示，或需引导用户到系统设置手动开启。
        case notGranted

        /// 是否已授权。
        var isGranted: Bool { self == .granted }
    }

    /// 当前授权状态。
    ///
    /// - Note: 不传 `AXTrustedCheckOptionPrompt`，避免每次查询都触发系统弹窗。
    ///   弹窗只在用户主动点击按钮时才应该出现。
    static var status: Status {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .notGranted
    }

    /// 请求辅助功能权限。
    ///
    /// 仅在用户**尚未拒绝过**时才会看到系统弹窗；已被拒绝时本方法
    /// 无可见效果，此时应引导用户走 `openAccessibilitySettings()`。
    ///
    /// - Returns: 调用后的状态。注意系统弹窗是异步的，返回
    ///   `.notGranted` 不代表用户拒绝了授权，可能只是还没来得及点。
    @MainActor
    @discardableResult
    static func requestPermission() -> Status {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .notGranted
    }

    /// 打开系统设置的「辅助功能」面板。
    ///
    /// 这是「点了没反应」时唯一可靠的出口：无论系统弹窗是否还能出现，
    /// 用户都能在这里直接勾选 Lumi。
    ///
    /// - Returns: 是否成功交给系统处理。
    @MainActor
    @discardableResult
    static func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
