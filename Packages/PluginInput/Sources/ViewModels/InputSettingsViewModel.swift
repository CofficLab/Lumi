import Foundation
import Combine
import AppKit

@MainActor
public class InputSettingsViewModel: ObservableObject {
    @Published var rules: [InputRule] = []
    @Published var availableSources: [InputSource] = []
    @Published var isEnabled: Bool = true
    @Published var runningApps: [NSRunningApplication] = []
    @Published var selectedApp: NSRunningApplication?
    @Published var selectedSourceID: String = ""
    
    private var service = InputService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        service.$config
            .sink { [weak self] config in
                self?.rules = config.rules
                self?.isEnabled = config.isEnabled
            }
            .store(in: &cancellables)
            
        service.$availableInputSources
            .assign(to: &$availableSources)
        
        refreshRunningApps()
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
