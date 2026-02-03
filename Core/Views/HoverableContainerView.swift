import SwiftUI
import Combine

/// 悬停协调器，用于管理多个悬停容器之间的互斥状态
class HoverCoordinator: ObservableObject {
    static let shared = HoverCoordinator()
    
    @Published var visibleID: String?
    
    private var hideWorkItem: DispatchWorkItem?
    
    /// 报告悬停状态变化
    /// - Parameters:
    ///   - id: 容器 ID
    ///   - isHovering: 是否处于悬停状态
    func onHover(id: String, isHovering: Bool) {
        // 确保在主线程执行
        DispatchQueue.main.async {
            if isHovering {
                // 如果是新的悬停，取消之前的隐藏任务
                self.hideWorkItem?.cancel()
                self.hideWorkItem = nil
                
                // 立即显示当前 ID（互斥：这会隐式关闭其他 ID）
                if self.visibleID != id {
                    self.visibleID = id
                }
            } else {
                // 如果离开的是当前显示的 ID，则启动延迟隐藏
                // 注意：这里我们只关心当前显示的 ID 丢失了悬停。
                // 如果离开的是非当前 ID（例如已经被互斥关闭了），则忽略。
                if self.visibleID == id {
                    let item = DispatchWorkItem { [weak self] in
                        // 再次检查是否仍然是这个 ID（防止竞态）
                        if self?.visibleID == id {
                            self?.visibleID = nil
                        }
                    }
                    self.hideWorkItem = item
                    // 延迟 0.3s 隐藏，给予用户从内容移动到 popover 的时间，
                    // 以及给予 popover 出现并捕获鼠标的时间。
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
                }
            }
        }
    }
    
    /// 强制关闭指定 ID 的悬停
    func close(id: String) {
        DispatchQueue.main.async {
            if self.visibleID == id {
                self.visibleID = nil
            }
        }
    }
}

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

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @State private var isPresented = false

    // MARK: - Initializer

    init(detailView: Detail, id: String = UUID().uuidString, @ViewBuilder content: () -> Content) {
        self.detailView = detailView
        self.id = id
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        return content
            .background(background(isHovering: isPresented))
            .animation(.easeInOut(duration: 0.2), value: isPresented)
            .onHover { hovering in
                coordinator.onHover(id: self.id, isHovering: hovering)
            }
            .popover(isPresented: $isPresented, arrowEdge: .leading) {
                detailView
                    .onHover { hovering in
                        coordinator.onHover(id: self.id, isHovering: hovering)
                    }
            }
            .onReceive(coordinator.$visibleID) { visibleID in
                let shouldShow = (visibleID == self.id)
                if isPresented != shouldShow {
                    isPresented = shouldShow
                }
            }
            .onChange(of: isPresented) { newValue in
                // 如果是用户手动关闭（例如点击外部），则通知协调器
                if !newValue && coordinator.visibleID == self.id {
                    coordinator.close(id: self.id)
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
