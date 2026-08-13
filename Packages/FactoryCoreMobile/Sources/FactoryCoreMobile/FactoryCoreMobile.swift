import KernelHosting
import KernelLumi
import SwiftUI

/// iOS 宿主引擎门面。
///
/// 与 macOS 的 `FactoryCore` 对应：它不提供窗口 / 工具栏 / 菜单栏等桌面 chrome，
/// 而是把插件通过 `kernel.workspace` 注册的面板用 iOS 原生
/// （`NavigationStack` / `TabView` / `sheet` / 导航栏工具栏）渲染出来。
///
/// 内核生命周期复用平台中性的 `KernelHosting`，确保双宿主不漂移。
@MainActor
public enum FactoryCoreMobile {
    /// 组装并呈现主界面：启动内核 → 渲染活跃视图容器 / 边栏 / 工具栏。
    public static func makeMainScene(
        plugins: [any LumiPlugin],
        enabledPluginIDs: Set<String> = [],
        initialContainerID: String? = nil,
        requiresAllCoreServices: Bool = false
    ) -> some View {
        MobileHostRoot(
            plugins: plugins,
            enabledPluginIDs: enabledPluginIDs,
            initialContainerID: initialContainerID,
            requiresAllCoreServices: requiresAllCoreServices
        )
    }
}

/// 异步启动内核，就绪后切换到 `MobileAppLayout`。
private struct MobileHostRoot: View {
    let plugins: [any LumiPlugin]
    let enabledPluginIDs: Set<String>
    let initialContainerID: String?
    let requiresAllCoreServices: Bool
    @State private var kernel: KernelLumi?
    @State private var bootError: String?

    var body: some View {
        ZStack {
            if let kernel {
                MobileAppLayout(kernel: kernel)
            } else if let bootError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Failed to start").font(.headline)
                    Text(bootError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                let booted = try await KernelHosting.createKernel(
                    plugins: plugins,
                    enabledPluginIDs: enabledPluginIDs,
                    requiresAllCoreServices: requiresAllCoreServices
                )
                if let id = initialContainerID {
                    booted.workspace?.activateContainer(id: id)
                }
                kernel = booted
            } catch {
                bootError = error.localizedDescription
            }
        }
    }
}
