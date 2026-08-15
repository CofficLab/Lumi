import SwiftUI

/// `ToolbarProviding` 的默认实现：返回一个最简的空工具栏占位视图。
///
/// 骨架阶段使用：仅用于验证「内核 → 工厂 → App → 工具栏」链路。
/// 宿主应注入自己的实现（如基于 AppTitleToolbar 的完整工具栏）。
@MainActor
public final class DefaultToolbarProviding: ToolbarProviding {
    public init() {}

    public func makeToolbarView() -> AnyView {
        AnyView(
            HStack {
                Spacer()
                Text("Toolbar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(height: 44)
        )
    }
}
