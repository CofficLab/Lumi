import Foundation
import AppKit
import Combine
import Carbon

@MainActor
class InputService: ObservableObject {
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
            print("[InputPlugin] Switching to \(rule.inputSourceID) for \(app.localizedName ?? bundleID)")
            switchInputSource(to: rule.inputSourceID)
        } else if let defaultID = config.defaultInputSourceID {
            // Optional: Switch to default if no rule exists
            // print("[InputPlugin] Switching to default \(defaultID)")
            // switchInputSource(to: defaultID)
        }
    }
    
    func switchInputSource(to sourceID: String) {
        guard let source = availableInputSources.first(where: { $0.id == sourceID }) else {
            print("[InputPlugin] Source \(sourceID) not found")
            return
        }
        source.select()
        currentInputSource = source
    }
    
    func addRule(for app: NSRunningApplication, sourceID: String) {
        guard let bundleID = app.bundleIdentifier else { return }
        let rule = InputRule(appBundleID: bundleID, appName: app.localizedName ?? bundleID, inputSourceID: sourceID)
        
        if let index = config.rules.firstIndex(where: { $0.appBundleID == bundleID }) {
            config.rules[index] = rule
        } else {
            config.rules.append(rule)
        }
    }
    
    func removeRule(id: String) {
        config.rules.removeAll(where: { $0.id == id })
    }
    
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
    
    func refreshSources() {
        self.availableInputSources = InputSource.getAll().filter { $0.category == "TISCategoryKeyboardInputSource" && $0.isSelectable }
    }
}
