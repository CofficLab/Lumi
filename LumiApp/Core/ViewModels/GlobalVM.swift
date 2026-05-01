import SwiftUI

/// 全局服务 VM：主题管理。
@MainActor
final class GlobalVM: ObservableObject {
    // MARK: - 主题管理

    /// 主题管理器
    let themeManager = ThemeManager()
}
