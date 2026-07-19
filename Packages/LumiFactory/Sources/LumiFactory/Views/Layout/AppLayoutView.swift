import LumiKernel
import LumiUI
import SwiftUI

/// 新版应用主布局
///
/// 基于 `LumiKernel` 构建，消费插件注册的视图容器。当前为最小可用实现，
/// 后续随插件迁移逐步恢复 panel、chat、status bar 等高级布局能力。
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    /// 当前布局服务提供的激活分区信息。
    private var layoutInfo: LayoutStateInfo {
        kernel.layout?.state ?? LayoutStateInfo()
    }

    var body: some View {
        let containers = kernel.allViewContainers
        let selected = selectedContainer(from: containers)

        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    kernel: kernel,
                    containers: containers
                )

                AppDivider(.vertical)

                if let selected {
                    selected.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()

            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text("没有可用的视图容器")
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textSecondary)

            Text("请启用至少一个提供视图容器的插件")
                .font(.appCaption)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectedContainer(from containers: [ViewContainerItem]) -> ViewContainerItem? {
        let activeID = layoutInfo.activeSectionID
        if !activeID.isEmpty,
           let container = containers.first(where: { $0.id == activeID }) {
            return container
        }
        return containers.first
    }
}
