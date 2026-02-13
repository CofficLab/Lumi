import Foundation
import Network
import NetworkExtension
import SwiftUI

extension NEFilterFlow {
    /// Get local port
    func getLocalPort() -> String {
        guard let socketFlow = self as? NEFilterSocketFlow else {
            return ""
        }

        guard let endpoint = socketFlow.localFlowEndpoint as? Network.NWEndpoint else { return "" }
        switch endpoint {
        case .hostPort(_, let port):
            return String(describing: port)
        default:
            return ""
        }
    }

    /// Get hostname
    func getHostname() -> String {
        guard let socketFlow = self as? NEFilterSocketFlow else {
            return ""
        }

        guard let endpoint = socketFlow.remoteFlowEndpoint as? Network.NWEndpoint else { return "" }
        switch endpoint {
        case .hostPort(let host, _):
            return String(describing: host)
        default:
            return ""
        }
    }

    /// Get App ID
    func getAppId() -> String {
        // Try to access the property directly if possible, or fallback to KVC
        if #available(macOS 10.15, *) {
            // sourceAppIdentifier is public API
            // But strictness might vary. 
            // The original code used value(forKey:) which suggests KVC.
            // We'll stick to KVC for now to match original behavior, 
            // but normally self.sourceAppIdentifier should work if available.
             return (self.value(forKey: "sourceAppIdentifier") as? String) ?? ""
        }
        return ""
    }

    func getAppUniqueId() -> String {
        return ""
    }
}
