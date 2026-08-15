import SwiftUI

/// `DocsViewProviding` 的默认实现：持有「关于」与「说明书」视图。
///
/// 插件通过 `setAboutView(_:)` / `setManualView(_:)` 注入；未设置时
/// `makeAboutView()` / `makeManualView()` 返回占位提示。
@MainActor
public final class DefaultDocsViewProviding: DocsViewProviding {
    private var aboutView: AnyView?
    private var manualView: AnyView?

    public init() {}

    public func setAboutView(_ view: AnyView?) {
        aboutView = view
    }

    public func setManualView(_ view: AnyView?) {
        manualView = view
    }

    public func makeAboutView() -> AnyView {
        aboutView ?? AnyView(DocsPlaceholderView(label: "No About"))
    }

    public func makeManualView() -> AnyView {
        manualView ?? AnyView(DocsPlaceholderView(label: "No Manual"))
    }
}

/// 文档占位视图。
private struct DocsPlaceholderView: View {
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
