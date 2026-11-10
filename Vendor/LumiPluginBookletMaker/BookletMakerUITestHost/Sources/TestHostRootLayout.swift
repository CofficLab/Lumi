import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderToolbar
import SwiftUI

/// 测试宿主的根布局：顶部工具栏 +（左侧 ActivityBar + 内容区 | 右侧 Rail）。
///
/// 为什么不用 `RootViewProviding.makeRootView()`：
/// 公开的 `DefaultRootViewProviding.makeRootView()` 只返回内容区，工具栏、
/// ActivityBar、Rail 三个区域会被丢弃——完整的「工作台」布局在宿主专属的
/// 私有实现里。测试宿主拿不到那个包，因此在这里按同样的结构自行拼装。
///
/// 这样拼装出的层级与真实宿主一致（工具栏在上、ActivityBar 在最左、Rail 在
/// 最右），UI 测试里的坐标关系与元素归属才和真实 App 可比。
struct TestHostRootLayout: View {
    let toolbar: (any ToolbarProviding)?
    let activityBar: (any ActivityBarProviding)?
    let rail: (any RailViewProviding)?
    let contentView: (any ContentViewProviding)?

    var body: some View {
        VStack(spacing: 0) {
            if let toolbar {
                toolbar.makeToolbarView()
                    .frame(height: 44)
            }

            HStack(spacing: 0) {
                if let activityBar {
                    activityBar.makeActivityBarView()
                        .frame(width: 52)
                }

                contentView?.makeContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let rail, rail.hasVisibleTabs {
                    Divider()
                    rail.makeRailView()
                        .frame(width: 300)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
