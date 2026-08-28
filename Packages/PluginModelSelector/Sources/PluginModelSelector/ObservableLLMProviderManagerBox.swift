import Combine
import Foundation
import ProviderLLMManager

/// SwiftUI 友好的内核 `LLMManaging` 包装器。
///
/// SwiftUI 的 `@ObservedObject` 不支持 `any LLMManaging` 类型的
/// existentials（`ObservableObject` 要求具体类型，报错
/// `type 'any LLMManaging' cannot conform to 'ObservableObject'`）。
///
/// 解法与旧版 `KernelLumi.ObservableMessageSendingBox` 一致：用具体类包装
/// 协议实例，并把它的 `objectWillChange` 桥接到自己的 publisher 上，视图即可：
/// ```swift
/// @ObservedObject var box: ObservableLLMProviderManagerBox
/// box.manager.selectedProviderID
/// ```
@MainActor
public final class ObservableLLMProviderManagerBox: ObservableObject {
    /// 被包装的 LLM Provider 管理器实例。
    public let manager: any LLMManaging

    /// 把 manager.objectWillChange 转发到 self.objectWillChange。
    private var cancellable: AnyCancellable?

    public init(manager: any LLMManaging) {
        self.manager = manager
        // 协议存在类型擦除：先把 publisher 转成 AnyPublisher 让类型对齐。
        self.cancellable = manager.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
