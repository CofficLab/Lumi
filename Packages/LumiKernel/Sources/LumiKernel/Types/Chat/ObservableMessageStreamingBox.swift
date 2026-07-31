import Combine
import Foundation

/// SwiftUI 友好的 `MessageStreaming` 包装器。
///
/// 与 `ObservableMessageSendingBox` 同理:SwiftUI 的 `@ObservedObject` 不支持
/// `any MessageStreaming` 这样的存在类型,需要用具体类包装,把 service 的
/// `objectWillChange` 桥接到自己的 publisher 上。
///
/// **为何需要独立订阅**:`MessageStreaming` 在流式期间高频变更(`@Published`
/// currentStreamingRow/currentStage 每个 chunk 都更新)。若经 kernel 的全局
/// objectWillChange 转发,会广播给所有订阅 kernel 的视图(20+),拖慢整个 app。
/// 用本包装器让消费视图(如 `MessageListView`)精确订阅 store,绕开全局广播。
///
/// 用法:
/// ```swift
/// @StateObject private var streamingBox = ObservableMessageStreamingBox()
/// // 在 onAppear/task 里绑定:
/// streamingBox.bind(kernel.messageStreaming)
/// // 视图里读:streamingBox.service?.currentStreamingRow
/// ```
@MainActor
public final class ObservableMessageStreamingBox: ObservableObject {
    /// 被包装的服务实例。绑定前为 nil。
    public private(set) var service: (any MessageStreaming)?

    private var cancellable: AnyCancellable?

    public init() {}

    /// 绑定(或重新绑定)一个 `MessageStreaming` 服务。
    /// 重复绑定同一实例为 no-op;绑定不同实例会切换订阅。
    public func bind(_ service: (any MessageStreaming)?) {
        // 已绑定同一实例:跳过,避免重复订阅。
        if (service != nil && service === self.service) { return }
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
