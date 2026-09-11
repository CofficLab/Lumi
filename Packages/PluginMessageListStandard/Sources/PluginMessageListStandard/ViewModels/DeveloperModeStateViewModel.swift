import Foundation

/// 消息列表共享的开发者模式状态源。
///
/// 由插件组装层的 `DeveloperModeStateObserver` 订阅外部事件并直接修改；
/// 所有消息行观察同一个实例，不再逐行创建外部 Observer。
@MainActor
final class DeveloperModeStateViewModel: ObservableObject {
    @Published private(set) var isDeveloperModeEnabled = false

    /// 外部事件写入（Observer 调用）。
    func update(isDeveloperModeEnabled: Bool) {
        guard self.isDeveloperModeEnabled != isDeveloperModeEnabled else { return }
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
    }
}
