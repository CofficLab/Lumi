import Foundation
import KitSuperLog
import AppKit
import Carbon
import os

@MainActor
public class InputService: ObservableObject, SuperLog {
    public nonisolated static let emoji = "⌨️"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "InputPlugin")
    public static let shared = InputService()

    @Published var config: InputConfig {
        didSet {
            saveConfig()
        }
    }

    @Published var currentInputSource: InputSource?
    @Published var availableInputSources: [InputSource] = []
    @Published var lastActiveAppBundleID: String?

    private var eventObserver: InputEventObserver?
    private let configKey = "InputPluginConfig"
    private let settingsStore = InputPluginLocalStore()

    private init() {
        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(Self.t)Input source service initialized")
            }
        }

        // Load config
        if let data = settingsStore.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(InputConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = InputConfig()
        }

        // Load sources
        self.availableInputSources = InputSource.getAll().filter { $0.category == "TISCategoryKeyboardInputSource" && $0.isSelectable }
        self.currentInputSource = InputSource.current()

        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(self.t)Loaded \(self.availableInputSources.count) input sources")
            }
        }

        startMonitoring()
    }
    
    public func startMonitoring() {
        eventObserver?.cancel()
        eventObserver = InputEventObserver(
            onApplicationActivation: { [weak self] app in
                self?.handleAppActivation(app)
            },
            onInputSourceChange: { [weak self] in
                self?.currentInputSource = InputSource.current()
            }
        )
    }
    
    private func handleAppActivation(_ app: NSRunningApplication) {
        guard config.isEnabled, let bundleID = app.bundleIdentifier else { return }
        lastActiveAppBundleID = bundleID

        if let rule = config.rules.first(where: { $0.appBundleID == bundleID }) {
            if Self.verbose {
                if InputService.verbose {
                                    InputService.logger.info("\(self.t)Switching to input source: \(rule.inputSourceID) for app \(app.localizedName ?? bundleID)")
                }
            }
            switchInputSource(to: rule.inputSourceID)
        } else if config.defaultInputSourceID != nil {
            // Optional: Switch to default if no rule exists
            // if Self.verbose {
            //     InputService.logger.info("\(self.t)Switching to default input source: \(config.defaultInputSourceID)")
            // }
            // switchInputSource(to: config.defaultInputSourceID)
        }
    }

    public func switchInputSource(to sourceID: String) {
        guard let source = availableInputSources.first(where: { $0.id == sourceID }) else {
            if InputService.verbose {
                            InputService.logger.error("\(self.t)Input source not found: \(sourceID)")
            }
            return
        }
        source.select()
        currentInputSource = source
        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(self.t)Switched to input source: \(source.id)")
            }
        }
    }

    public func addRule(for app: NSRunningApplication, sourceID: String) {
        guard let bundleID = app.bundleIdentifier else { return }
        let rule = InputRule(appBundleID: bundleID, appName: app.localizedName ?? bundleID, inputSourceID: sourceID)

        if let index = config.rules.firstIndex(where: { $0.appBundleID == bundleID }) {
            config.rules[index] = rule
        } else {
            config.rules.append(rule)
        }

        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(self.t)Added input source rule: \(bundleID) -> \(sourceID)")
            }
        }
    }

    public func removeRule(id: String) {
        config.rules.removeAll(where: { $0.id == id })
        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(self.t)Removed input source rule: \(id)")
            }
        }
    }

    private func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            if !settingsStore.set(data, forKey: configKey), InputService.verbose {
                InputService.logger.error("\(self.t)Failed to persist input plugin config")
            }
        } catch {
            if InputService.verbose {
                InputService.logger.error("\(self.t)Failed to encode input plugin config: \(error.localizedDescription)")
            }
        }
    }

    public func refreshSources() {
        self.availableInputSources = InputSource.getAll().filter { $0.category == "TISCategoryKeyboardInputSource" && $0.isSelectable }
        if Self.verbose {
            if InputService.verbose {
                            InputService.logger.info("\(self.t)Refreshed input source list: \(self.availableInputSources.count) available")
            }
        }
    }
}
