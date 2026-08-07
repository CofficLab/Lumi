import Combine
import Foundation

/// SwiftUI 友好的 `WorkspaceProviding` 窄播包装器。
///
/// 与 `ObservableMessageStreamingBox` 同理：SwiftUI 的 `@ObservedObject` 不支持
/// `any WorkspaceProviding` 这样的存在类型，需要用具体类包装，把 service 的
/// `objectWillChange` 桥接到自己的 publisher 上。
///
/// **为何需要独立订阅**：布局层大量视图（StatusBar / AppTitleToolbar /
/// ChatHeader / ChatToolbar / RailTabBar / ActivityBar 等）只依赖 workspace 一个
/// service。若经 kernel 的全局 objectWillChange 转发，project/conversations/settings
/// 等无关服务变更都会让这些布局视图重求值（每条都是 ForEach 重活）。用本包装器让
/// 消费视图精确订阅 workspace service，绕开全局广播。
///
/// 用法：
/// ```swift
/// @StateObject private var box = ObservableWorkspaceBox()
/// // 在 task 里绑定：
/// box.bind(kernel.workspace)
/// // 视图里读：box.service?.statusBarItems(placement: .leading)
/// ```
@MainActor
public final class ObservableWorkspaceBox: ObservableObject {
    /// 被包装的服务实例。绑定前为 nil。
    public private(set) var service: (any WorkspaceProviding)?

    private var cancellable: AnyCancellable?

    public init() {}

    /// 绑定（或重新绑定）一个 `WorkspaceProviding` 服务。
    /// 重复绑定同一实例为 no-op；绑定不同实例会切换订阅。
    public func bind(_ service: (any WorkspaceProviding)?) {
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
