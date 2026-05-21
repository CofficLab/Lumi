import Combine
///
/// ## 初始化规则
///
/// 在 `MenuBarController` 中直接实例化，不通过 `RootContainer` 管理。
import SwiftUI

/// 菜单栏图标视图模型
class AppMenuBarIconVM: ObservableObject {
    @Published var isActive: Bool = false
    @Published var activeSources: Set<String> = []

    /// 插件提供的状态栏内容视图
    @Published var contentViews: [AnyView] = []
}

#Preview("LogoView - Snapshot") {
    LogoView(scene: .appIcon)
}
