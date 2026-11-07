import SwiftUI

private struct ToastWindowIDEnvironmentKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

public extension EnvironmentValues {
    /// 承载当前视图树的窗口标识（对应 SwiftUI `Window` / `WindowGroup` 的 id）。
    ///
    /// 窗口宿主在根部注入该值；持久化错误面板据此只在来源窗口渲染，
    /// 避免同一个错误在主窗口、设置窗口等多个窗口重复弹出。
    var toastWindowID: String? {
        get { self[ToastWindowIDEnvironmentKey.self] }
        set { self[ToastWindowIDEnvironmentKey.self] = newValue }
    }
}
