import SwiftUI

/// 右侧栏容器视图
///
/// 聚合所有插件提供的右侧栏 Section 视图，使用 VStack 垂直堆叠。
/// 每个插件通过 `addSidebarSections()` 提供一个或多个 Section，
/// 内核按插件 order 升序将所有 Section 垂直排列在右侧栏中。
struct RightSidebarContainerView: View {
    /// 插件提供的右侧栏 Section 视图列表（按插件 order 升序、数组顺序排列）
    let sections: [AnyView]

    var body: some View {
        guard !sections.isEmpty else {
            return AnyView(Color.clear)
        }

        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    section

                    // 非最后一个 section 之间添加分隔线
                    if index < sections.count - 1 {
                        GlassDivider()
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .frame(minWidth: 320, idealWidth: 400)
        )
    }
}

// MARK: - Preview

#Preview("Single Section") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity))
    ])
    .inRootView()
    .frame(height: 400)
}

#Preview("Multiple Sections") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity)),
        AnyView(Text("Input Area").frame(maxWidth: .infinity).padding(8)),
    ])
    .inRootView()
    .frame(height: 400)
}
