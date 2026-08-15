import SwiftUI

/// `ContentViewProviding` 的默认实现：持有当前主内容视图。
///
/// 插件通过 `setContentView(_:)` 注册主要内容（如设备信息视图）；
/// 未设置时 `makeContentView()` 返回占位提示。
@MainActor
public final class DefaultContentViewProviding: ContentViewProviding {
    private var contentView: AnyView?

    public init() {}

    public func setContentView(_ view: AnyView?) {
        contentView = view
    }

    public func makeContentView() -> AnyView {
        if let contentView {
            return contentView
        }
        return AnyView(ContentPlaceholderView())
    }
}

/// 内容区占位视图。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No Content")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
