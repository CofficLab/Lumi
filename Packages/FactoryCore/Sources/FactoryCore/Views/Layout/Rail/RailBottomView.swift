import KernelLumi
import LumiUI
import SwiftUI

/// Rail 底部区块视图
///
/// 固定在 `RailView` 底部，承载设置等快捷入口；后续可在此追加更多入口。
struct RailBottomView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()
            content
        }
    }

    /// 底部入口集合；将来新增功能在此追加即可。
    @ViewBuilder
    private var content: some View {
        settingsEntry
    }

    private var settingsEntry: some View {
        AppSidebarRow(
            title: String(localized: "Settings", bundle: .module),
            systemImage: "gearshape"
        ) {
            openWindow(id: AppBootstrap.settingsWindowID)
        }
        .help("Settings")
    }
}

#Preview {
    RailBottomView()
        .frame(width: 220)
        .background(Color.gray.opacity(0.1))
}
