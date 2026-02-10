import Combine
import SwiftUI

/// 状态栏图标视图模型
class StatusBarIconViewModel: ObservableObject {
    @Published var isActive: Bool = false
    @Published var activeSources: Set<String> = []

    /// 插件提供的状态栏内容视图
    @Published var contentViews: [AnyView] = []
}

#Preview("LogoView - Snapshot") {
    LogoView(variant: .appIcon)
        .inMagicContainer(.init(width: 500, height: 500), scale: 1)
}
