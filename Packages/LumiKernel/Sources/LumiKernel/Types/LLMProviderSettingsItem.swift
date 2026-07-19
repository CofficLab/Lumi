import Foundation
import SwiftUI

/// LLM 提供商设置项
///
/// 插件通过 `kernel.registerLLMProviderSettingsItem()` 注册提供商专属设置详情视图。
/// 为避免 LumiKernel 依赖具体 LLM 类型，provider 对象以 `Any` 传入并由消费方自行转换。
@MainActor
public struct LLMProviderSettingsItem {
    public let providerID: String
    private let contentBuilder: @MainActor @Sendable (Any) -> AnyView

    public init<Content: View>(
        providerID: String,
        @ViewBuilder content: @escaping @MainActor @Sendable (Any) -> Content
    ) {
        self.providerID = providerID
        self.contentBuilder = { AnyView(content($0)) }
    }

    /// 为指定提供商构建设置内容视图
    public func makeContent(for provider: Any) -> AnyView {
        contentBuilder(provider)
    }
}
