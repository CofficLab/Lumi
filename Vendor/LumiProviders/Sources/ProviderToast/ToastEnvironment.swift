import SwiftUI

private struct ToastProvidingEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (any ToastProviding)? = nil
}

/// 当前窗口可用的 Toast Provider。
///
/// 这是 SwiftUI 宿主的便捷注入方式；业务插件仍应优先通过内核解析
/// `ToastProviding`，以保持非视图代码可测试。
public extension EnvironmentValues {
    var toastProviding: (any ToastProviding)? {
        get { self[ToastProvidingEnvironmentKey.self] }
        set { self[ToastProvidingEnvironmentKey.self] = newValue }
    }
}
