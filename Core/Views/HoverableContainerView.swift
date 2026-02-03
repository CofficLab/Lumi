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

    // MARK: - State

    @State private var isHovering = false
    @State private var hideWorkItem: DispatchWorkItem?

    // MARK: - Initializer

    init(detailView: Detail, @ViewBuilder content: () -> Content) {
        self.detailView = detailView
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        content
            .background(background())
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { hovering in
                updateHoverState(hovering: hovering)
            }
            .popover(isPresented: $isHovering, arrowEdge: .leading) {
                detailView
                    .onHover { hovering in
                        updateHoverState(hovering: hovering)
                    }
            }
    }

    // MARK: - Private Methods

    private func background() -> some View {
        ZStack {
            if isHovering {
                Rectangle()
                    .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.2))
            } else {
                EmptyView()
            }
        }
    }

    private func updateHoverState(hovering: Bool) {
        // Cancel any pending hide action
        hideWorkItem?.cancel()
        hideWorkItem = nil

        if hovering {
            // If mouse enters either view, keep showing
            isHovering = true
        } else {
            // If mouse leaves, wait a bit before hiding
            // This gives time to move between the source view and the popover
            let workItem = DispatchWorkItem {
                isHovering = false
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
}

// MARK: - Preview

#Preview("Hoverable Container") {
    VStack(spacing: 20) {
        HoverableContainerView(detailView: Text("详情内容")) {
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
