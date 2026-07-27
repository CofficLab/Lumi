import LumiKernel
import TerminalCoreKit

@MainActor
public enum TerminalPluginBridge {
    public static var editorThemeIdProvider: (() -> String)?
}

/// TerminalPlugin 的 ViewModel 单例扩展
///
/// TerminalCoreKit 的 TerminalTabsViewModel 不提供单例，
/// 由 TerminalPlugin 在 App 层创建自己的共享实例。
extension TerminalTabsViewModel {
    /// TerminalPlugin 使用的全局单例
    ///
    /// 确保终端会话在整个应用生命周期中保持不变，
    /// 即使 SwiftUI 重建 TerminalMainView 也不会丢失状态。
    public static let shared = TerminalTabsViewModel(
        themeIdProvider: { TerminalPluginBridge.editorThemeIdProvider?() ?? "xcode-dark" }
    )
}
