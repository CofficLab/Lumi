import SwiftUI

/// `WindowProviding` 的默认实现：返回一个最简单的根视图。
///
/// 骨架阶段使用：仅展示一行文本，用于验证「内核 → 工厂 → App → 窗口」
/// 整条链路。宿主可提供自己的实现（如完整的 AppLayoutView）替换。
@MainActor
public final class DefaultWindowProviding: WindowProviding {
    public init() {}

    public func makeRootView() -> AnyView {
        AnyView(
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                Text("Hello from KernelFactory")
                    .font(.title)
                Text("WindowProviding · ProviderWindow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
        )
    }
}
