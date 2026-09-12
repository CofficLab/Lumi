import Foundation

/// 消息渲染器共享的界面状态（开发者模式等全局开关）。
///
/// 由插件组装层的 `MessageRendererStateObserver` 订阅外部事件并直接修改；
/// 所有渲染行观察同一个实例，不再逐行创建外部 Observer。
@MainActor
final class MessageRendererStateViewModel: ObservableObject {
    @Published private(set) var isDeveloperModeEnabled = false

    /// 外部事件写入（Observer 调用）。
    func update(isDeveloperModeEnabled: Bool) {
        guard self.isDeveloperModeEnabled != isDeveloperModeEnabled else { return }
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
    }
}
