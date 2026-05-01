import SwiftUI

/// 右侧栏容器视图
///
/// 聚合所有插件提供的右侧栏视图，使用 HSplitView 水平排列。
/// 当有多个右侧栏时，会在它们之间自动添加分隔线。
/// 每个侧边栏的宽度比例按插件 ID 独立持久化。
struct RightSidebarContainerView: View {
    /// 插件提供的右侧栏视图列表（按插件 order 升序排列）
    let views: [AnyView]

    /// 持久化 storage key 前缀
    private let storageKeyPrefix = "Split.Panel.RightSidebar"

    var body: some View {
        guard !views.isEmpty else {
            return AnyView(Color.clear)
        }

        if views.count == 1 {
            return AnyView(
                views[0]
                    .background(SplitViewWidthPersistence(storageKey: "\(storageKeyPrefix).0"))
            )
        } else {
            var result: AnyView = AnyView(
                views[0]
                    .background(SplitViewWidthPersistence(storageKey: "\(storageKeyPrefix).0"))
            )

            for (index, view) in views.dropFirst().enumerated() {
                let wrapped = AnyView(
                    HSplitView {
                        result
                        view
                            .background(SplitViewWidthPersistence(storageKey: "\(storageKeyPrefix).\(index + 1)"))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: "\(storageKeyPrefix).combined"))
                )
                result = wrapped
            }

            return result
        }
    }
}

#Preview("Single Sidebar") {
    RightSidebarContainerView(views: [
        AnyView(Text("Sidebar 1").frame(width: 350))
    ])
    .inRootView()
    .frame(height: 400)
}

#Preview("Multiple Sidebars") {
    RightSidebarContainerView(views: [
        AnyView(Text("Chat").frame(width: 350)),
        AnyView(Text("Preview").frame(width: 300))
    ])
    .inRootView()
    .frame(height: 400)
}
