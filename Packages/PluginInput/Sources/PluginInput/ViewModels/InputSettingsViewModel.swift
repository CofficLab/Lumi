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
