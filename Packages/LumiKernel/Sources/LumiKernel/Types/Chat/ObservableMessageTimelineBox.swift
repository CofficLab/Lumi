import Combine
import Foundation

/// SwiftUI 友好的 `MessageTimelineProviding` 包装器
///
/// 与 `ObservableMessageSendingBox` 同理:SwiftUI 的 `@ObservedObject` 不支持
/// `any MessageTimelineProviding` 这样的存在类型,需要用具体类包装,把 service 的
/// `objectWillChange` 桥接到自己的 publisher 上。
///
/// **为何需要独立订阅**:`MessageTimelineProviding` 在流式期间高频变更
/// (每个流式 token 都会重算 `displayRows`)。该服务注册到 kernel 时不转发
/// objectWillChange(见 `registerMessageTimelineProvider`),消费视图必须用
/// 本包装器精确订阅,绕开 kernel 全局广播。
///
/// 用法:
/// ```swift
/// if let timeline = kernel.messageTimeline {
///     let box = boxHolder.box(for: timeline)
///     MessageListContentView(box: box)
/// }
/// ```
@MainActor
public final class ObservableMessageTimelineBox: ObservableObject {
    /// 被包装的服务实例
    public let service: any MessageTimelineProviding

    /// 把 service.objectWillChange 转发到 self.objectWillChange
    private var cancellable: AnyCancellable?

    public init(service: any MessageTimelineProviding) {
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
