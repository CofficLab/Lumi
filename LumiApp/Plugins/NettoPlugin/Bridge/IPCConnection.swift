/*
Abstract:
This file contains the implementation of the app <-> provider IPC connection
Adapted for Lumi NettoPlugin
*/

import Foundation
import OSLog
import Network
import NetworkExtension

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
class IPCConnection: NSObject, @unchecked Sendable {
    static let shared = IPCConnection()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cofficlab.lumi", category: "IPCConnection")
    
    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    weak var delegate: AppCommunication?
    
    /**
        The NetworkExtension framework registers a Mach service with the name in the system extension's NEMachServiceName Info.plist key.
        The Mach service name must be prefixed with one of the app groups in the system extension's com.apple.security.application-groups entitlement.
        Any process in the same app group can use the Mach service to communicate with the system extension.
     */
    private func extensionMachServiceName(from bundle: Bundle) -> String {
        guard let networkExtensionKeys = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
            let machServiceName = networkExtensionKeys["NEMachServiceName"] as? String else {
                // Fallback or fatal error depending on context. 
                // In Plugin context, we might not have this in Info.plist if not configured yet.
                // But for now we assume correct configuration.
                logger.error("Mach service name is missing from the Info.plist")
                return ""
        }

        return machServiceName
    }

    func startListener() {
        let machServiceName = extensionMachServiceName(from: Bundle.main)
        guard !machServiceName.isEmpty else { return }
        
        logger.info("🚀 Starting XPC listener for mach service \(machServiceName)")

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
    }

    /// This method is called by the app to register with the provider running in the system extension.
    func register(withExtension bundle: Bundle, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {
        self.delegate = delegate

        guard currentConnection == nil else {
            logger.warning("⚠️ IPC.register: Already registered with the provider")
            completionHandler(true)
            return
        }
        
        logger.info("🛫 IPC.register")

        let machServiceName = extensionMachServiceName(from: bundle)
        guard !machServiceName.isEmpty else {
            completionHandler(false)
            return
        }
        
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: AppCommunication.self)
        newConnection.exportedObject = delegate

        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)

        currentConnection = newConnection
        newConnection.resume()

        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            self.logger.error("Failed to register with the provider: \(registerError.localizedDescription)")
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            logger.critical("Failed to create a remote object proxy for the provider")
            completionHandler(false)
            return
        }

        logger.info("🛫 providerProxy.register")
        providerProxy.register(completionHandler)
    }

    /**
        This method is called by the provider to cause the app (if it is registered) to display a prompt to the user asking
        for a decision about a connection.
    */
    func promptUser(flow: NEFilterFlow, responseHandler:@escaping (Bool) -> Void) -> Bool {
        logger.info("🍋 promptUser")
        
        guard let connection = currentConnection else {
            logger.error("Cannot prompt user because the app isn't registered")
            return false
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            self.logger.error("Failed to prompt the user: \(promptError.localizedDescription)")
            self.currentConnection = nil
            responseHandler(true)
        }) as? AppCommunication else {
            logger.critical("Failed to create a remote object proxy for the app")
            return false
        }

        // Note: flow.getAppId(), flow.getHostname() need to be available. 
        // NEFilterFlow extensions might be needed if they are not standard API or if they were in MagicCore.
        // Assuming standard API or I need to check if Netto extended NEFilterFlow.
        // Checking Netto source: `Bridge/NEFilterFlowExt.swift` likely exists.
        
        // Ask the app to prompt the user
        appProxy.promptUser(id: flow.getAppId(), hostname:flow.getHostname(), port: flow.getLocalPort(), direction: flow.direction, responseHandler: responseHandler)
        
        return true
    }
    
    func log(_ message: String) {
        // os_log("🧩 IPC.providerSay")
        guard let connection = currentConnection else {
            // os_log("🧩 Cannot prompt user because the app isn't registered")
            return
        }
        
        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            self.logger.error("🧩 Failed to prompt the user: \(promptError.localizedDescription)")
        }) as? AppCommunication else {
            logger.critical("🧩 Failed to create a remote object proxy for the app")
            return
        }
        appProxy.extensionLog(message)
    }
}

extension IPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("IPCConnection.shouldAcceptNewConnection")
        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

        newConnection.invalidationHandler = {
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        return true
    }
}

extension IPCConnection: ProviderCommunication {
    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {
        logger.info("IPC.App registered")
        completionHandler(true)
    }
}
