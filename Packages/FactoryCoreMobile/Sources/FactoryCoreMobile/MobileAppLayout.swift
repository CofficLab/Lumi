import LumiKernel
import SwiftUI

/// iOS 主布局：把 `kernel.workspace` 注册的面板渲染成 iOS 原生界面。
///
/// - 视图容器（`allViewContainers`）：多容器用 `TabView`，单容器直接展示。
/// - 活跃容器内容（`currentViewContainer.makeView`）填充主区域。
/// - 工具栏项（`allTitleToolbarItems`）放到导航栏。
/// - 边栏项（`allPanelRailTabItems`，按活跃容器过滤）通过工具栏按钮以 sheet 呈现。
///
/// 与 macOS `AppLayoutView` 读同一个注册表，只是渲染方式不同。
struct MobileAppLayout: View {
    @ObservedObject var kernel: LumiKernel
    @State private var refreshTick: Int = 0
    @State private var isRailPresented = false

    var body: some View {
        let workspace = kernel.workspace
        let containers = workspace?.allViewContainers ?? []
        let active = workspace?.currentViewContainer ?? containers.first

        Group {
            if containers.count > 1 {
                tabRoot(containers: containers, active: active)
            } else if let active {
                content(for: active)
            } else {
                ContentUnavailableView("No content", systemImage: "tray")
            }
        }
        .onWorkspaceContributionsDidChange { refreshTick &+= 1 }
        .onActiveViewContainerIDDidChange { _ in refreshTick &+= 1 }
        .id(refreshTick)
    }

    @ViewBuilder
    private func tabRoot(containers: [ViewContainerItem], active: ViewContainerItem?) -> some View {
        TabView(selection: Binding(
            get: { active?.id },
            set: { id in
                if let id { kernel.workspace?.activateContainer(id: id) }
            }
        )) {
            ForEach(containers) { container in
                content(for: container)
                    .tabItem { Label(container.title, systemImage: container.systemImage) }
                    .tag(container.id)
            }
        }
    }

    @ViewBuilder
    private func content(for container: ViewContainerItem) -> some View {
        NavigationStack {
            Group {
                if let makeView = container.makeView {
                    makeView()
                } else {
                    ContentUnavailableView(container.title, systemImage: container.systemImage)
                }
            }
            .navigationTitle(Text(container.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !railItems(for: container.id).isEmpty {
                        Button { isRailPresented = true } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(titleToolbarItems()) { item in item.makeView() }
                }
            }
            .sheet(isPresented: $isRailPresented) {
                railSheet(for: container.id)
            }
        }
    }

    private func railItems(for containerID: String) -> [PanelRailTabItem] {
        (kernel.workspace?.allPanelRailTabItems ?? [])
            .filter { $0.visibility.isVisible(in: containerID) }
            .sorted { $0.order < $1.order }
    }

    private func titleToolbarItems() -> [LumiTitleToolbarItem] {
        (kernel.workspace?.allTitleToolbarItems ?? [])
            .sorted { $0.order < $1.order }
    }

    @ViewBuilder
    private func railSheet(for containerID: String) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(railItems(for: containerID)) { tab in
                        tab.makeView()
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isRailPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
