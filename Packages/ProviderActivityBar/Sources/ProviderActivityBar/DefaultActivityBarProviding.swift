import LumiUI
import SwiftUI

/// `ActivityBarProviding` 的默认实现：持有注入的 `ActivityBarItem`，
/// 渲染为 48pt 宽的竖直入口栏（与旧版 `FactoryCore.ActivityBar` 视觉一致）。
///
@MainActor
public final class DefaultActivityBarProviding: ActivityBarProviding, ObservableObject {
    @Published public private(set) var items: [ActivityBarItem] = []
    @Published public private(set) var activeItemID: String?

    public init() {}

    public func registerItems(_ items: [ActivityBarItem]) {
        self.items = items.sorted { $0.order < $1.order }
        let nextActiveID: String?
        if let activeItemID, self.items.contains(where: { $0.id == activeItemID }) {
            nextActiveID = activeItemID
        } else {
            nextActiveID = self.items.first?.id
        }
        setActiveItemID(nextActiveID)
    }

    public func activateItem(id: String?) {
        guard id == nil || items.contains(where: { $0.id == id }) else { return }
        setActiveItemID(id)
    }

    public func makeActivityBarView() -> AnyView {
        AnyView(ActivityBarView(provider: self))
    }

    private func setActiveItemID(_ id: String?) {
        guard activeItemID != id else { return }
        activeItemID = id
        for item in items {
            item.onActiveItemChanged(id)
        }
    }
}

/// 竖直渲染 ActivityBar 项的视图。
///
/// 视觉与旧版 `FactoryCore.ActivityBar` 保持一致：
/// - 48pt 宽的 `.panel` 表面 + 右侧 `theme.divider` 分隔线（`borderTrailing()`）；
/// - 每个入口复用 `AppActivityIconButton`（18pt 图标、左侧 2.5pt 主题色指示条、
///   hover 高亮与 LumiMotion 动画），激活态由 `activeItemID` 判定；
/// - 内容溢出时滚动，配合上下 8pt 渐隐遮罩提示可滚动；
/// - 右键菜单提供「打开设置」入口（与旧版一致，通过 `lumi.openSettings` 通知）。
private struct ActivityBarView: View {
    @ObservedObject var provider: DefaultActivityBarProviding

    var body: some View {
        Group {
            if provider.shouldDisplayActivityBar {
                VStack(spacing: 6) {
                    ActivityBarScrollableItemList(
                        items: provider.items,
                        activeItemID: provider.activeItemID
                    ) { item in
                        provider.activateItem(id: item.id)
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
                        // 与旧版 ActivityBar 一致：发出通知，由主窗口根视图监听并打开设置窗口。
                        NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
                    } label: {
                        Label("打开设置", systemImage: "gearshape")
                    }
                }
            }
        }
    }
}

/// ActivityBar 可滚动的入口列表（与旧版 `ActivityBarScrollableContainerList` 行为一致）：
/// - 内容溢出时启用滚动（隐藏系统滚动指示器，顶部/底部 8pt 渐隐遮罩暗示可滚动）；
/// - 内容不足时退化为普通垂直布局，不显示任何滚动提示。
private struct ActivityBarScrollableItemList: View {
    /// 上下渐隐遮罩的高度
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
            .padding(.vertical, 2) // 避免渐隐遮罩切到边缘图标
        }
        .mask(fadeMask)
    }

    /// 上下两端 8pt 渐隐到透明的 LinearGradient，提示该方向上还有更多内容可滚动。
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

/// 打开设置窗口的通知名（与 KernelLumi 的 `lumi.openSettings` 同字符串，通知可互通）。
private extension Notification.Name {
    static let lumiOpenSettings = Notification.Name("lumi.openSettings")
}
