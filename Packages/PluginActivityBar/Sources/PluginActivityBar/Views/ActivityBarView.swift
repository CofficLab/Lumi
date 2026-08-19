import SwiftUI
import LumiUI
import ProviderActivityBar

/// 打开设置窗口的通知名（与 KernelLumi 的 `lumi.openSettings` 同字符串，通知可互通）。
private extension Notification.Name {
    static let lumiOpenSettings = Notification.Name("lumi.openSettings")
}

/// 竖直渲染 ActivityBar 项的视图。
///
/// 视觉与旧版 `FactoryCore.ActivityBar` 保持一致（即与 `DefaultActivityBarProviding`
/// 相同的渲染），但在此**完全自实现**，不依赖 `DefaultActivityBarProviding`：
/// - 48pt 宽的 `.panel` 表面 + 右侧 `theme.divider` 分隔线（`borderTrailing()`）；
/// - 每个入口复用 `AppActivityIconButton`（18pt 图标、左侧 2.5pt 主题色指示条、
///   hover 高亮与 LumiMotion 动画），激活态由 `activeItemID` 判定；
/// - 内容溢出时滚动，配合上下 8pt 渐隐遮罩提示可滚动；
/// - 右键菜单提供「打开设置」入口（与旧版一致，通过 `lumi.openSettings` 通知）。
internal struct ActivityBarView: View {
    @ObservedObject var provider: ActivityBarProvider

    var body: some View {
        VStack(spacing: 6) {
            if provider.items.isEmpty {
                Spacer(minLength: 0)
            } else {
                ActivityBarScrollableItemList(
                    items: provider.items,
                    activeItemID: provider.activeItemID
                ) { item in
                    provider.activateItem(id: item.id)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .frame(maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
        .borderTrailing()
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
            } label: {
                Label("打开设置", systemImage: "gearshape")
            }
        }
    }
}

/// ActivityBar 可滚动的入口列表（与旧版 `ActivityBarScrollableContainerList` 行为一致）：
/// - 内容溢出时启用滚动（隐藏系统滚动指示器，顶部/底部 8pt 渐隐遮罩暗示可滚动）；
/// - 内容不足时退化为普通垂直布局，不显示任何滚动提示。
private struct ActivityBarScrollableItemList: View {
    private let fadeHeight: CGFloat = 8

    let items: [ActivityBarItem]
    let activeItemID: String?
    let onSelect: (ActivityBarItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    AppActivityIconButton(
                        systemImage: item.systemImage,
                        label: item.title,
                        isActive: activeItemID == item.id
                    ) {
                        onSelect(item)
                    }
                    .id(item.id)
                }
            }
            .padding(.vertical, 2)
        }
        .mask(fadeMask)
    }

    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)

            Color.black

            LinearGradient(
                colors: [Color.black, Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)
        }
    }
}
