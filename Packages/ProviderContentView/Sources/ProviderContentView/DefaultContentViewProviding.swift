import SwiftUI

/// `ContentViewProviding` 的默认实现：持有当前主内容视图。
///
/// 插件通过 `setContentView(_:)` 注册主要内容（如设备信息视图）；
/// 未设置时 `makeContentView()` 返回占位提示。
@MainActor
public final class DefaultContentViewProviding: ContentViewProviding, ObservableObject {
    @Published fileprivate var contentView: AnyView?

    public init() {}

    public func setContentView(_ view: AnyView?) {
        contentView = view
    }

    public func makeContentView() -> AnyView {
        AnyView(ContentHostView(provider: self))
    }
}

/// 稳定挂在 RootView 中并观察 Provider；后续 `setContentView` 会直接刷新内容区。
private struct ContentHostView: View {
    @ObservedObject var provider: DefaultContentViewProviding

    var body: some View {
        if let contentView = provider.contentView {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 内容区占位视图。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No Content", bundle: .module))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
