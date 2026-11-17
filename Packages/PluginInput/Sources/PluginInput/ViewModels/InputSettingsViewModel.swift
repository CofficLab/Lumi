import Foundation
import AppKit
import Combine

@MainActor
public class InputSettingsViewModel: ObservableObject {
    @Published var rules: [InputRule] = []
    @Published var availableSources: [InputSource] = []
    @Published var isEnabled: Bool = true
    @Published var runningApps: [NSRunningApplication] = []
    @Published var selectedApp: NSRunningApplication?
    @Published var selectedSourceID: String = ""
    
    let service = InputService.shared

    private var workspaceCancellables = Set<AnyCancellable>()

    private let runningAppsProvider: () -> [NSRunningApplication]

    public init(
        runningAppsProvider: @escaping () -> [NSRunningApplication] = {
            NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        }
    ) {
        self.runningAppsProvider = runningAppsProvider
        refreshRunningApps()
        // 页面常驻时应用启动/退出也要反映到选择器：onAppear 只在出现时快照一次，
        // 之后列表会一直停留在旧状态（#785）。订阅随实例释放自动取消。
        let center = NSWorkspace.shared.notificationCenter
        center.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshRunningApps() }
            }
            .store(in: &workspaceCancellables)
        center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshRunningApps() }
            }
            .store(in: &workspaceCancellables)
    }

    func apply(config: InputConfig) {
        rules = config.rules
        isEnabled = config.isEnabled
    }

    func apply(availableSources: [InputSource]) {
        self.availableSources = availableSources
    }
    
    public func refreshRunningApps() {
        runningApps = runningAppsProvider()
    }

    /// 重新枚举系统输入源并同步到界面。
    ///
    /// 输入源列表此前只在 `InputService` 单例初始化时读取一次，运行期间通过
    /// macOS 设置新增的键盘不会出现，必须重启 Lumi。设置页出现时调用这里，
    /// 保证候选列表反映当前系统状态。
    public func refreshSources() {
        service.refreshSources()
        availableSources = service.availableInputSources
    }
    
    public func addRule() {
        guard let app = selectedApp, !selectedSourceID.isEmpty else { return }
        service.addRule(for: app, sourceID: selectedSourceID)
        selectedApp = nil
        selectedSourceID = ""
    }
    
    public func removeRule(at offsets: IndexSet) {
        offsets.compactMap { index in
            rules.indices.contains(index) ? rules[index] : nil
        }.forEach { rule in
            service.removeRule(id: rule.id)
        }
    }
    
    public func toggleEnabled() {
        service.config.isEnabled.toggle()
    }
}
