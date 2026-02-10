import Foundation
import Combine
import AppKit

@MainActor
class InputSettingsViewModel: ObservableObject {
    @Published var rules: [InputRule] = []
    @Published var availableSources: [InputSource] = []
    @Published var isEnabled: Bool = true
    @Published var runningApps: [NSRunningApplication] = []
    @Published var selectedApp: NSRunningApplication?
    @Published var selectedSourceID: String = ""
    
    private var service = InputService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
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
    
    func refreshRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
    }
    
    func addRule() {
        guard let app = selectedApp, !selectedSourceID.isEmpty else { return }
        service.addRule(for: app, sourceID: selectedSourceID)
        selectedApp = nil
        selectedSourceID = ""
    }
    
    func removeRule(at offsets: IndexSet) {
        offsets.map { rules[$0] }.forEach { rule in
            service.removeRule(id: rule.id)
        }
    }
    
    func toggleEnabled() {
        service.config.isEnabled.toggle()
    }
}
