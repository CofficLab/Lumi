import Combine
import Foundation

/// SwiftUI 友好的 `LLMProviderManaging` 窄播包装器。
///
/// 与 `ObservableWorkspaceBox`、`ObservableConversationsBox` 同理：SwiftUI 的
/// `@ObservedObject` 不支持 `any LLMProviderManaging` 这样的存在类型，需要用具体类
/// 包装，把 service 的 `objectWillChange` 桥接到自己的 publisher 上。
///
/// **为何需要独立订阅**：状态栏可见性门控视图（MiniMax / Zhipu 的
/// `StatusBarVisibilityView`）只关心 `selectedProviderID` 一个值，用来决定是否显示
/// 各自的配额状态栏。若经 kernel 的全局 objectWillChange 转发，project/conversations/
/// settings 等无关服务变更都会让这些视图重求值。用本包装器让消费视图精确订阅
/// llmProvider service，绕开全局广播。
///
/// 用法：
/// ```swift
/// @StateObject private var box = ObservableLLMProviderBox()
/// // 在 task 里绑定：
/// box.bind(kernel.llmProvider)
/// // 视图里读：box.service?.selectedProviderID
/// ```
@MainActor
public final class ObservableLLMProviderBox: ObservableObject {
    /// 被包装的服务实例。绑定前为 nil。
    public private(set) var service: (any LLMProviderManaging)?

    private var cancellable: AnyCancellable?

    public init() {}

    /// 绑定（或重新绑定）一个 `LLMProviderManaging` 服务。
    /// 重复绑定同一实例为 no-op；绑定不同实例会切换订阅。
    public func bind(_ service: (any LLMProviderManaging)?) {
        // 已绑定同一实例：跳过，避免重复订阅。
        if service != nil && service === self.service { return }
        self.service = service
        cancellable = nil
        guard let service else { return }
        cancellable = service.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
