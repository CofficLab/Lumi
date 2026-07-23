import Combine
import Foundation

/// SwiftUI 友好的 `MessageSending` 包装器
///
/// SwiftUI 的 `@ObservedObject` 不支持 `any MessageSending` 类型的 existentials
/// (`error: type 'any MessageSending' cannot conform to 'ObservableObject'`)。
/// 原因是 `ObservableObject` 要求具体类型。
///
/// 解法:用一个**具体类**作为 wrapper,内部持有 `MessageSending` 实例并把它的
/// `objectWillChange` 桥接到自己的 publisher 上,这样 SwiftUI 视图可以:
/// ```swift
/// @ObservedObject var box: ObservableMessageSendingBox
/// box.service.pendingAttachments
/// ```
///
/// 跨插件、跨包观察 `MessageSending` 协议类型时使用此包装器。
@MainActor
public final class ObservableMessageSendingBox: ObservableObject {
    /// 被包装的服务实例
    public let service: any MessageSending

    /// 把 service.objectWillChange 转发到 self.objectWillChange
    private var cancellable: AnyCancellable?

    public init(service: any MessageSending) {
        self.service = service
        // 协议存在类型擦除,先把 publisher 转成 AnyPublisher 让类型对齐
        self.cancellable = service.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}