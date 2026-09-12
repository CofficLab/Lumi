import AppKit
import Combine
import Foundation

/// 右键菜单设置/预览共享的唯一数据来源。
///
/// 负责配置读写、模板增删、开关与重置等业务状态；外部操作（打开系统设置、
/// 打开数据目录）也收敛在本 ViewModel，View 只读取本 ViewModel。
@MainActor
final class RClickSettingsViewModel: ObservableObject {
    private let configManager: RClickConfigManager
    private var cancellables: Set<AnyCancellable> = []

    /// 当前右键菜单配置（由 `RClickConfigManager` 持久化）。
    @Published private(set) var config: RClickConfig

    init(configManager: RClickConfigManager) {
        self.configManager = configManager
        self.config = configManager.config
        configManager.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newConfig in
                self?.config = newConfig
            }
            .store(in: &cancellables)
    }

    // MARK: - 派生状态

    /// 是否显示新建文件子菜单预览（新建文件启用且有模板时）。
    var shouldShowNewFilePreview: Bool {
        let isNewFileEnabled = config.items.contains { $0.type == .newFile && $0.isEnabled }
        let hasEnabledTemplates = config.fileTemplates.contains { $0.isEnabled }
        return isNewFileEnabled && hasEnabledTemplates
    }

    /// 新建文件菜单项（可能为 nil）。
    var newFileItem: RClickMenuItem? {
        config.items.first { $0.type == .newFile }
    }

    // MARK: - 用户意图

    func toggleItem(_ item: RClickMenuItem) {
        configManager.toggleItem(item)
    }

    func toggleTemplate(_ template: NewFileTemplate) {
        configManager.toggleTemplate(template)
    }

    func deleteTemplate(_ template: NewFileTemplate) {
        configManager.deleteTemplate(template)
    }

    @discardableResult
    func addTemplate(name: String, extensionName: String, content: String) -> Bool {
        let template = NewFileTemplate(name: name, extensionName: extensionName, content: content)
        return configManager.addTemplate(template)
    }

    func resetToDefaults() {
        configManager.resetToDefaults()
    }

    func openFinderExtensionSettings() {
        // macOS 13+ 路径一致：通用 → 登录项与扩展 → 扩展
        let urlString = "x-apple.systempreferences:com.apple.Extensions-List"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func openDataDirectory() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
        guard let url = appSupport else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
