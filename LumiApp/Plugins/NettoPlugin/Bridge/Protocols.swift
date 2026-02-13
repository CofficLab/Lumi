import Foundation
import NetworkExtension

/// App --> Provider IPC
@objc protocol ProviderCommunication {
    /// Register the app with the provider
    /// - Parameter completionHandler: Registration result callback
    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// Provider --> App IPC
@objc protocol AppCommunication {
    /// Ask user if connection should be allowed
    /// - Parameters:
    ///   - id: App Identifier
    ///   - hostname: Hostname
    ///   - port: Port
    ///   - direction: Traffic direction
    ///   - responseHandler: Response handler
    func promptUser(id: String, hostname: String, port: String, direction: NETrafficDirection, responseHandler: @escaping (Bool) -> Void)
    
    /// User approval needed
    func needApproval()
    
    /// Pass logs from extension
    /// - Parameter words: Log content
    func extensionLog(_ words: String)
}
