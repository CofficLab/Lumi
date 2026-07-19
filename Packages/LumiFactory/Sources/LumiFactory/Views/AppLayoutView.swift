import LumiKernel
import SwiftUI

/// 应用主布局视图
///
/// 显示 ActivityBar 和当前选中的视图容器内容。
public struct AppLayoutView: View {
    @ObservedObject var kernel: LumiKernel
    @State private var activeContainerID: String?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        let containers = kernel.allViewContainers
        let selectedContainer = containers.first { $0.id == activeContainerID } ?? containers.first

        HStack(spacing: 0) {
            // 左侧活动栏
            ActivityBar(
                kernel: kernel,
                activeContainerID: $activeContainerID
            )

            // 分隔线
            Divider()

            // 主内容区域
            if let container = selectedContainer {
                container.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 无视图容器时的占位
                EmptyStateView()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            // 默认选中第一个容器
            if activeContainerID == nil, let first = containers.first {
                activeContainerID = first.id
            }
        }
        .onChange(of: containers.map(\.id)) { _, newIDs in
            // 如果当前选中的容器被移除，选中第一个
            if let currentID = activeContainerID, !newIDs.contains(currentID) {
                activeContainerID = newIDs.first
            }
        }
    }
}

/// 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("没有可用的视图")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("请注册视图容器插件")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}