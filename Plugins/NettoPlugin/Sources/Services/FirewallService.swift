import Foundation
@preconcurrency import NetworkExtension
import SystemExtensions
import os
import SuperLogKit
import AppKit
import SwiftUI

public enum FilterStatus: String, CaseIterable {
    case stopped = "Stopped"
    case running = "Running"
    case error = "Error"
    case indeterminate = "Loading..."
    
    public var description: String { rawValue }
}

public class FirewallService: NSObject, ObservableObject, SuperLog, @unchecked Sendable {
    public static let shared = FirewallService()
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.netto")
    private var verbose: Bool = false
    
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
    public func refreshStatus() async {
        if NEFilterManager.shared().isEnabled {
            self.status = .running
        } else {
            self.status = .stopped
        }
    }
    
    public func startFilter() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { error in
            if let error = error {
                if self.verbose {
                                    self.logger.error("\(self.t)Failed to load filter configuration: \(error.localizedDescription)")
                }
                DispatchQueue.main.async { self.status = .error }
                return
            }
            
            if manager.providerConfiguration == nil {
                let providerConfiguration = NEFilterProviderConfiguration()
                // filterBrowsers 在 macOS 上不受支持，已弃用
                // providerConfiguration.filterBrowsers = true
                providerConfiguration.filterSockets = true
                manager.providerConfiguration = providerConfiguration
                manager.localizedDescription = "Lumi Netto Firewall"
            }
            
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error = error {
                    if self.verbose {
                                            self.logger.error("\(self.t)Failed to save filter configuration: \(error.localizedDescription)")
                    }
                    DispatchQueue.main.async { self.status = .error }
                } else {
                    if self.verbose {
                                            self.logger.info("\(self.t)Filter configuration saved successfully")
                    }
                    DispatchQueue.main.async { self.status = .running }
                }
            }
        }
    }
    
    public func stopFilter() {
        let manager = NEFilterManager.shared()
        manager.loadFromPreferences { error in
            if let error = error {
                if self.verbose {
                                    self.logger.error("\(self.t)Failed to load filter configuration: \(error.localizedDescription)")
                }
                return
            }
            
            manager.isEnabled = false
            manager.saveToPreferences { error in
                if let error = error {
                    if self.verbose {
                                            self.logger.error("\(self.t)Failed to disable filter: \(error.localizedDescription)")
                    }
                } else {
                    DispatchQueue.main.async { self.status = .stopped }
                }
            }
        }
    }
    
    // MARK: - Extension Management
    
    public func installExtension() {
        // This requires the extension bundle to be present in the app bundle
        // and System Extension entitlement.
        guard let extensionIdentifier = Bundle.main.object(forInfoDictionaryKey: "NettoExtensionIdentifier") as? String else {
            logger.error("\(self.t)NettoExtensionIdentifier not found in Info.plist")
            return
        }
        
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension FirewallService: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
    
    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("\(self.t)System extension requires user approval")
    }
    
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("\(self.t)System extension installation finished with result: \(result.rawValue)")
    }
    
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("\(self.t)System extension installation failed: \(error.localizedDescription)")
    }
}

extension FirewallService: AppCommunication {
    public func promptUser(id: String, hostname: String, port: String, direction: NETrafficDirection, responseHandler: @escaping (Bool) -> Void) {
        // Check existing setting
        if let setting = settingRepo.getSetting(for: id) {
            responseHandler(setting.allowed)
            logEvent(id: id, hostname: hostname, port: port, direction: direction, allowed: setting.allowed)
            return
        }

        let responder = FirewallPromptResponder(responseHandler)
        DispatchQueue.main.async {
            let allowed = self.presentConnectionPrompt(
                appId: id,
                hostname: hostname,
                port: port,
                direction: direction
            )
            self.settingRepo.setAllowed(appId: id, allowed: allowed)
            responder.respond(allowed)
            self.logEvent(id: id, hostname: hostname, port: port, direction: direction, allowed: allowed)
        }
    }
    
    public func needApproval() {
        // Handle need approval
    }
    
    public func extensionLog(_ words: String) {
        logger.debug("\(self.t)Extension: \(words)")
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

    @MainActor
    private func presentConnectionPrompt(
        appId: String,
        hostname: String,
        port: String,
        direction: NETrafficDirection
    ) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = LumiPluginLocalization.string("New Connection Request", bundle: .module)
        alert.informativeText = Self.connectionPromptMessage(
            appId: appId,
            hostname: hostname,
            port: port,
            direction: direction
        )
        alert.addButton(withTitle: LumiPluginLocalization.string("Allow", bundle: .module))
        alert.addButton(withTitle: LumiPluginLocalization.string("Block", bundle: .module))

        return alert.runModal() == .alertFirstButtonReturn
    }

    static func connectionPromptMessage(
        appId: String,
        hostname: String,
        port: String,
        direction: NETrafficDirection
    ) -> String {
        let endpoint = port.isEmpty ? hostname : "\(hostname):\(port)"
        let directionText: String
        switch direction {
        case .inbound:
            directionText = LumiPluginLocalization.string("Incoming", bundle: .module)
        case .outbound:
            directionText = LumiPluginLocalization.string("Outgoing", bundle: .module)
        case .any:
            directionText = LumiPluginLocalization.string("Any", bundle: .module)
        @unknown default:
            directionText = LumiPluginLocalization.string("Unknown", bundle: .module)
        }

        return "\(appId)\n\(directionText): \(endpoint)"
    }
}

private struct FirewallPromptResponder: @unchecked Sendable {
    private let responseHandler: (Bool) -> Void

    init(_ responseHandler: @escaping (Bool) -> Void) {
        self.responseHandler = responseHandler
    }

    func respond(_ allowed: Bool) {
        responseHandler(allowed)
    }
}
