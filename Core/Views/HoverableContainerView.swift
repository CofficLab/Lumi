import SwiftUI

/// 可悬停的容器视图，提供统一的 hover 背景高亮和 popover 效果
///
/// 使用示例：
/// ```swift
/// HoverableContainerView(detailView: NetworkHistoryDetailView()) {
///     VStack {
///         liveSpeedView
///         miniTrendView
///     }
/// }
/// ```
struct HoverableContainerView<Content: View, Detail: View>: View {
    // MARK: - Properties

    /// 详情视图（在 popover 中显示）
    let detailView: Detail

    /// 内容视图构建器
    let content: Content

    /// 唯一标识符，用于区分不同的悬停容器
    let id: String

    // MARK: - State

    @StateObject private var hoverStateManager = HoverStateManager.shared
    @State private var hideWorkItem: DispatchWorkItem?

    // MARK: - Initializer

    init(detailView: Detail, id: String = UUID().uuidString, @ViewBuilder content: () -> Content) {
        self.detailView = detailView
        self.id = id
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        let isHovering = hoverStateManager.isHovering(id: id)

        return content
            .background(background(isHovering: isHovering))
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { hovering in
                // ✅ 关键修复：只在 popover 未显示时处理主内容区的离开事件
                // 当 popover 显示时，鼠标进入 popover 会触发主内容区的 onHover(false)
                // 但这是正常的，不应该隐藏 popover
                if hovering {
                    // 鼠标进入：总是处理
                    print("[HoverableContainerView[\(id.prefix(10))]] Main content onHover: \(hovering)")
                    hoverStateManager.registerHover(id: id, isHovering: hovering, isPopover: false)
                } else if !isHovering {
                    // 鼠标离开且 popover 未显示：处理
                    print("[HoverableContainerView[\(id.prefix(10))]] Main content onHover: \(hovering)")
                    hoverStateManager.registerHover(id: id, isHovering: hovering, isPopover: false)
                } else {
                    // 鼠标离开但 popover 正在显示：忽略
                    print("[HoverableContainerView[\(id.prefix(10))]] Main content onHover: \(hovering) - ignored (popover is showing)")
                }
            }
            .popover(isPresented: .constant(isHovering), arrowEdge: .leading) {
                detailView
                    .onHover { hovering in
                        print("[HoverableContainerView[\(id.prefix(10))]] Popover onHover: \(hovering)")
                        // Popover 内部悬停：保持显示
                        hoverStateManager.registerHover(id: id, isHovering: true, isPopover: true)
                    }
            }
    }

    // MARK: - Private Methods

    private func background(isHovering: Bool) -> some View {
        ZStack {
            if isHovering {
                Rectangle()
                    .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.2))
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Preview

#Preview("Hoverable Container") {
    VStack(spacing: 20) {
        HoverableContainerView(detailView: Text("详情内容"), id: "preview1") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("网络监控")
                        .font(.headline)
                    Spacer()
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("下载速度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1.2 MB/s")
                            .font(.title2)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("上传速度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("256 KB/s")
                            .font(.title2)
                    }
                }
            }
            .padding()
            .background(.background.opacity(0.5))
        }
        .frame(width: 250)
    }
    .frame(width: 400, height: 300)
}
