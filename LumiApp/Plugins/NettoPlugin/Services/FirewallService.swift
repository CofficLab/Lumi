import Foundation
import NetworkExtension
import SystemExtensions
import OSLog
import AppKit
import SwiftUI

enum FilterStatus: String, CaseIterable {
    case stopped = "Stopped"
    case running = "Running"
    case error = "Error"
    case indeterminate = "Loading..."
    
    var description: String { rawValue }
}

class FirewallService: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = FirewallService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cofficlab.lumi", category: "FirewallService")
    
    @Published var status: FilterStatus = .indeterminate
    @Published var events: [FirewallEvent] = []
    
    private var ipc = IPCConnection.shared
    private let settingRepo = AppSettingRepo.shared
    
    override init() {
        super.init()
        Task {
            await refreshStatus()
        }
    }
    
    @MainActor
    func refreshStatus() async {
        if NEFilterManager.shared().isEnabled {
            self.status = .running
        } else {
            self.status = .stopped
        }
    }
    
    func startFilter() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { error in
            if let error = error {
                self.logger.error("Failed to load filter configuration: \(error.localizedDescription)")
                DispatchQueue.main.async { self.status = .error }
                return
            }
            
            if manager.providerConfiguration == nil {
                let providerConfiguration = NEFilterProviderConfiguration()
                providerConfiguration.filterBrowsers = true
                providerConfiguration.filterSockets = true
                manager.providerConfiguration = providerConfiguration
                manager.localizedDescription = "Lumi Netto Firewall"
            }
            
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error = error {
                    self.logger.error("Failed to save filter configuration: \(error.localizedDescription)")
                    DispatchQueue.main.async { self.status = .error }
                } else {
                    self.logger.info("Filter configuration saved successfully")
                    DispatchQueue.main.async { self.status = .running }
                }
            }
        }
    }
    
    func stopFilter() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { error in
            if let error = error {
                self.logger.error("Failed to load filter configuration: \(error.localizedDescription)")
                return
            }
            
            manager.isEnabled = false
            manager.saveToPreferences { error in
                if let error = error {
                    self.logger.error("Failed to disable filter: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async { self.status = .stopped }
                }
            }
        }
    }
    
    // MARK: - Extension Management
    
    func installExtension() {
        // This requires the extension bundle to be present in the app bundle
        // and System Extension entitlement.
        guard let extensionIdentifier = Bundle.main.object(forInfoDictionaryKey: "NettoExtensionIdentifier") as? String else {
            logger.error("NettoExtensionIdentifier not found in Info.plist")
            return
        }
        
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension FirewallService: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension requires user approval")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension installation finished with result: \(result.rawValue)")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension installation failed: \(error.localizedDescription)")
    }
}

extension FirewallService: AppCommunication {
    func promptUser(id: String, hostname: String, port: String, direction: NETrafficDirection, responseHandler: @escaping (Bool) -> Void) {
        // Check existing setting
        if let setting = settingRepo.getSetting(for: id) {
            responseHandler(setting.allowed)
            logEvent(id: id, hostname: hostname, port: port, direction: direction, allowed: setting.allowed)
            return
        }
        
        // If no setting, prompt user (or default allow for now to avoid blocking)
        // Ideally we show a notification with actions.
        // For simplicity in this plugin version, we default to ALLOW and log it.
        // User can then change it in the UI.
        
        let defaultAction = true // Allow by default
        settingRepo.setAllowed(appId: id, allowed: defaultAction)
        responseHandler(defaultAction)
        logEvent(id: id, hostname: hostname, port: port, direction: direction, allowed: defaultAction)
        
        // TODO: Implement proper User Notification or Alert
        /*
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "New Connection Request"
            alert.informativeText = "\(id) wants to connect to \(hostname):\(port)"
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Block")
            let response = alert.runModal()
            let allowed = (response == .alertFirstButtonReturn)
            self.settingRepo.setAllowed(appId: id, allowed: allowed)
            responseHandler(allowed)
        }
        */
    }
    
    func needApproval() {
        // Handle need approval
    }
    
    func extensionLog(_ words: String) {
        logger.debug("Extension: \(words)")
    }
    
    private func logEvent(id: String, hostname: String, port: String, direction: NETrafficDirection, allowed: Bool) {
        let event = FirewallEvent(
            address: hostname,
            port: port,
            sourceAppIdentifier: id,
            status: allowed ? .allowed : .rejected,
            direction: direction
        )
        DispatchQueue.main.async {
            self.events.insert(event, at: 0)
            if self.events.count > 100 { self.events.removeLast() }
        }
    }
}
