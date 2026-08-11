import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Activity Bar 视图
///
/// 显示所有视图容器（插件注册的 ViewContainer），用户点击切换激活容器。
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听两个事件：
/// - `.workspaceContributionsDidChange`：容器清单注册/注销/重建后更新；
/// - `.activeViewContainerIDDidChange`：用户切换容器时同步高亮（保留原 onAppear 行为）。
struct ActivityBar: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "ui.activity-bar")
    nonisolated static let emoji = "📍"
    nonisolated static let verbose = true

    @LumiTheme private var theme
    @Environment(\.openWindow) private var openWindow
    let kernel: LumiKernel

    @State private var containers: [ViewContainerItem] = []
    @State private var highlightedContainerID: String?

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _containers = State(initialValue: kernel.workspace?.allViewContainers ?? [])
        _highlightedContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        VStack(spacing: 6) {
            if !containers.isEmpty {
                containerList
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
        #if DEBUG
        .overlay(
            Rectangle()
                .fill(theme.warning.opacity(0.20))
                .allowsHitTesting(false)
        )
        #endif
        .onWorkspaceContributionsDidChange {
            containers = kernel.workspace?.allViewContainers ?? []
        }
        .onActiveViewContainerIDDidChange { activeID in
            highlightedContainerID = activeID
        }
    }

    // MARK: - Container List

    @ViewBuilder
    private var containerList: some View {
        ActivityBarScrollableContainerList(
            containers: containers,
            highlightedContainerID: highlightedContainerID
        ) { container in
            highlightedContainerID = container.id
            kernel.workspace?.activateContainer(id: container.id)
        }
    }
}
