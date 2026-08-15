import SwiftUI

/// `RootViewProviding` 的默认实现：持有注入的工具栏与 ActivityBar 视图，
/// 组合成「顶部工具栏 + 内容区（左侧 ActivityBar）」的根布局
/// （模仿 AppLayoutView 结构）。
///
/// 骨架阶段使用：内容区为居中占位提示，宿主可注入自己的实现
/// （如基于 WindowProviding 内容 + AppTitleToolbar 的完整布局）。
@MainActor
public final class DefaultRootViewProviding: RootViewProviding {
    private var toolbarView: AnyView?
    private var activityBarView: AnyView?

    public init() {}

    public func setToolbarView(_ view: AnyView?) {
        toolbarView = view
    }

    public func setActivityBarView(_ view: AnyView?) {
        activityBarView = view
    }

    public func makeRootView() -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                if let toolbarView {
                    toolbarView
                    Divider()
                }

                HStack(spacing: 0) {
                    if let activityBarView {
                        activityBarView
                        Divider()
                    }

                    // 内容区占位：骨架阶段显示提示文本，真正的布局由宿主实现注入。
                    ContentPlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
    }
}

/// 内容区占位视图。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Root View")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
