import Foundation

/// 开发者模式开关唯一的数据来源与交互入口。
///
/// View 只依赖本 ViewModel；外部状态变化由 `DeveloperModeObserver`
/// 直接修改本 ViewModel。
@MainActor
final class DeveloperModeViewModel: ObservableObject {
    @Published private(set) var isEnabled = false

    private let capability: any DeveloperModeCapability

    init(capability: any DeveloperModeCapability) {
        self.capability = capability
    }

    /// 外部事件写入（Observer 调用）。
    func update(isEnabled: Bool) {
        guard self.isEnabled != isEnabled else { return }
        self.isEnabled = isEnabled
    }

    /// 用户切换意图。
    func toggle() {
        capability.toggle()
    }
}
