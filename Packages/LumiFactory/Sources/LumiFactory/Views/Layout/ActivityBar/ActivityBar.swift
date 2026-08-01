import LumiKernel
import LumiUI
import SwiftUI

struct ActivityBar: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        VStack(spacing: 6) {
            if let workspace = kernel.workspace {
                containerList(workspace: workspace)
            } else {
                ActivityBarErrorView()
            }

            Spacer()

            AppIconButton(
                systemImage: "gearshape",
                size: .regular
            ) {
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .help("Settings")
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .appSurface(style: .panel, cornerRadius: 0)
        .borderTrailing()
    }

    // MARK: - Container List

    @ViewBuilder
    private func containerList(workspace: any WorkspaceProviding) -> some View {
        ForEach(workspace.allViewContainers) { container in
            AppActivityIconButton(
                systemImage: container.systemImage,
                label: container.title,
                isActive: workspace.activeViewContainerID == container.id
            ) {
                workspace.activateContainer(id: container.id)
            }
        }
    }
}

// MARK: - 预览

#if DEBUG
    #Preview("ActivityBar - Normal") {
        // 正常态预览需构造真实 kernel,这里仅展示错误分支
        ActivityBarErrorPreview()
            .frame(height: 400)
    }

    #Preview("ActivityBar - Workspace Unavailable") {
        ActivityBarErrorPreview()
            .frame(height: 400)
    }

    /// 包装一层让预览能编译通过(完整预览需真实 LumiKernel 注入,
    /// 在单元测试或 LumiApp 启动窗口中查看)。
    private struct ActivityBarErrorPreview: View {
        var body: some View {
            VStack(spacing: 6) {
                ActivityBarErrorView()
                Spacer()
                AppIconButton(systemImage: "gearshape", size: .regular) {}
                    .help("Settings")
            }
            .padding(.vertical, 8)
            .frame(width: 48)
            .background(Color.gray.opacity(0.15))
        }
    }
#endif
