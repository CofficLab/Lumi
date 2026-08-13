import KernelLumi
import LumiUI
import SwiftUI

/// ActivityBar 可滚动的容器列表
///
/// 行为：
/// - 内容溢出时启用滚动（隐藏系统滚动指示器，仅靠顶部/底部渐隐遮罩暗示可滚动）；
/// - 内容不足时退化为普通垂直布局，不显示任何滚动提示；
/// - 每个容器对应一个 `AppActivityIconButton`，激活态由调用方传入的 `highlightedContainerID` 判定。
///
/// 设计动机：当插件数量增长、图标超过可用高度时，原 `VStack + Spacer` 会从底部裁掉图标。
/// 这里通过 `ScrollView(.vertical, showsIndicators: false)` 提供滚动能力，配合顶部/底部
/// 的 8pt 渐隐遮罩，提示用户「这里有更多内容」。
struct ActivityBarScrollableContainerList: View {
    @LumiTheme private var theme

    let containers: [ViewContainerItem]
    let highlightedContainerID: String?
    let onSelect: (ViewContainerItem) -> Void

    /// 上下渐隐遮罩的高度
    private let fadeHeight: CGFloat = 8

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(containers) { container in
                    AppActivityIconButton(
                        systemImage: container.systemImage,
                        label: container.title,
                        isActive: highlightedContainerID == container.id
                    ) {
                        onSelect(container)
                    }
                    .id(container.id)
                }
            }
            .padding(.vertical, 2) // 避免渐隐遮罩切到边缘图标
        }
        .mask(fadeMask) // 顶部/底部渐隐，暗示「这里可以滚动」
    }

    // MARK: - View

    /// 上下两端 8pt 渐隐到透明的 LinearGradient，
    /// 让越靠近边缘的图标越淡，提示用户该方向上还有更多内容可滚动。
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

// MARK: - Preview

#if DEBUG
    /// 预览辅助：构造 N 个示例容器
    private func previewContainers(_ count: Int) -> [ViewContainerItem] {
        (0 ..< count).map { index in
            ViewContainerItem(
                id: "preview-\(index)",
                title: "Container \(index)",
                systemImage: "folder"
            )
        }
    }

    #Preview("Few - 不溢出") {
        ActivityBarScrollableContainerList(
            containers: previewContainers(4),
            highlightedContainerID: nil,
            onSelect: { _ in }
        )
        .frame(width: 48, height: 400)
        .background(Color.gray.opacity(0.15))
    }

    #Preview("Many - 溢出可滚动") {
        ActivityBarScrollableContainerList(
            containers: previewContainers(20),
            highlightedContainerID: "preview-3",
            onSelect: { _ in }
        )
        .frame(width: 48, height: 360)
        .background(Color.gray.opacity(0.15))
    }
#endif