import Foundation
import AppKit

@MainActor
public class InputSettingsViewModel: ObservableObject {
    @Published var rules: [InputRule] = []
    @Published var availableSources: [InputSource] = []
    @Published var isEnabled: Bool = true
    @Published var runningApps: [NSRunningApplication] = []
    @Published var selectedApp: NSRunningApplication?
    @Published var selectedSourceID: String = ""
    
    let service = InputService.shared
    
    public init() {
        refreshRunningApps()
    }

    func apply(config: InputConfig) {
        rules = config.rules
        isEnabled = config.isEnabled
    }

    func apply(availableSources: [InputSource]) {
        self.availableSources = availableSources
    }
    
    public func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
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
