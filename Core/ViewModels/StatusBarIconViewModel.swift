import Combine
import SwiftUI

/// 状态栏图标视图模型
class StatusBarIconViewModel: ObservableObject {
    @Published var isActive: Bool = false
    @Published var activeSources: Set<String> = []
}

#Preview("LogoView - Snapshot") {
    LogoView(variant: .appIcon, design: .smartLight)
        .inMagicContainer(.init(width: 500, height: 500), scale: 1)
}
