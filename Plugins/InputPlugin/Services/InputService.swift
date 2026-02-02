import Foundation
import AppKit
import Combine
import Carbon
import OSLog
import MagicKit

@MainActor
class InputService: ObservableObject, SuperLog {
    nonisolated static let emoji = "⌨️"
    nonisolated static let verbose = false

    static let shared = InputService()

    @Published var config: InputConfig {
        didSet {
            saveConfig()
        }
    }

    @Published var currentInputSource: InputSource?
    @Published var availableInputSources: [InputSource] = []
    @Published var lastActiveAppBundleID: String?

    private var cancellables = Set<AnyCancellable>()
    private let configKey = "InputPluginConfig"

    private init() {
        if Self.verbose {
            os_log("\(Self.t)输入源服务已初始化")
        }

        // Load config
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(InputConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = InputConfig()
        }

        // Load sources
        self.availableInputSources = InputSource.getAll().filter { $0.category == "TISCategoryKeyboardInputSource" && $0.isSelectable }
        self.currentInputSource = InputSource.current()

        if Self.verbose {
            os_log("\(self.t)加载了 \(self.availableInputSources.count) 个输入源")
        }

        startMonitoring()
    }
    
    func startMonitoring() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { notification -> NSRunningApplication? in
                return notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            }
            .sink { [weak self] app in
                self?.handleAppActivation(app)
            }
            .store(in: &cancellables)
            
        // Also listen for input source changes to update UI
        NotificationCenter.default.publisher(for: NSTextInputContext.keyboardSelectionDidChangeNotification)
            .sink { [weak self] _ in
                self?.currentInputSource = InputSource.current()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppActivation(_ app: NSRunningApplication) {
        guard config.isEnabled, let bundleID = app.bundleIdentifier else { return }
        lastActiveAppBundleID = bundleID

        if let rule = config.rules.first(where: { $0.appBundleID == bundleID }) {
            if Self.verbose {
                os_log("\(self.t)切换到输入源: \(rule.inputSourceID) 用于应用 \(app.localizedName ?? bundleID)")
            }
            switchInputSource(to: rule.inputSourceID)
        } else if let defaultID = config.defaultInputSourceID {
            // Optional: Switch to default if no rule exists
            // if Self.verbose {
            //     os_log("\(self.t)切换到默认输入源: \(defaultID)")
            // }
            // switchInputSource(to: defaultID)
        }
    }

    func switchInputSource(to sourceID: String) {
        guard let source = availableInputSources.first(where: { $0.id == sourceID }) else {
            os_log(.error, "\(self.t)输入源未找到: \(sourceID)")
            return
        }
        source.select()
        currentInputSource = source
        if Self.verbose {
            os_log("\(self.t)已切换到输入源: \(source.id)")
        }
    }

    func addRule(for app: NSRunningApplication, sourceID: String) {
        guard let bundleID = app.bundleIdentifier else { return }
        let rule = InputRule(appBundleID: bundleID, appName: app.localizedName ?? bundleID, inputSourceID: sourceID)

        if let index = config.rules.firstIndex(where: { $0.appBundleID == bundleID }) {
            config.rules[index] = rule
        } else {
            config.rules.append(rule)
        }

        if Self.verbose {
            os_log("\(self.t)添加输入源规则: \(bundleID) -> \(sourceID)")
        }
    }

    func removeRule(id: String) {
        config.rules.removeAll(where: { $0.id == id })
        if Self.verbose {
            os_log("\(self.t)移除输入源规则: \(id)")
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    func refreshSources() {
        self.availableInputSources = InputSource.getAll().filter { $0.category == "TISCategoryKeyboardInputSource" && $0.isSelectable }
        if Self.verbose {
            os_log("\(self.t)刷新输入源列表: \(self.availableInputSources.count) 个可用")
        }
    }
}
