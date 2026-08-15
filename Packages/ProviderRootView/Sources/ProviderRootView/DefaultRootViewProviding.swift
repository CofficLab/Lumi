import SwiftUI

/// `RootViewProviding` 的默认实现：持有注入的工具栏、ActivityBar、Rail
/// 与主内容视图，组合成「顶部工具栏 + 内容区（左侧 ActivityBar，右侧 Rail）」
/// 的根布局（模仿 AppLayoutView 结构）。
///
/// 主内容未注入时显示居中占位提示；注入后（通常来自 `ContentViewProviding`）
/// 显示为内容区。
@MainActor
public final class DefaultRootViewProviding: RootViewProviding {
    private var toolbarView: AnyView?
    private var activityBarView: AnyView?
    private var railView: AnyView?
    private var contentView: AnyView?

    public init() {}

    public func setToolbarView(_ view: AnyView?) {
        toolbarView = view
    }

    public func setActivityBarView(_ view: AnyView?) {
        activityBarView = view
    }

    public func setRailView(_ view: AnyView?) {
        railView = view
    }

    public func setContentView(_ view: AnyView?) {
        contentView = view
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

                    if let railView {
                        railView
                        Divider()
                    }

                    // 内容区：已注入主内容则显示之，否则显示占位提示。
                    Group {
                        if let contentView {
                            contentView
                        } else {
                            ContentPlaceholderView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if os(macOS)
            // 与旧版 Lumi（AppLayoutView）一致：内容延伸进标题栏区域，
            // 工具栏从窗口顶部开始渲染，红绿灯悬浮在工具栏上。
            .ignoresSafeArea()
            #endif
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
