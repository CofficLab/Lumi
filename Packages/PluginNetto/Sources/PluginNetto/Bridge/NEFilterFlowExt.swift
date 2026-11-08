import Foundation
import Network
import NetworkExtension
import SwiftUI

/// 根据流量方向选择与主机名配对的目标端口。
enum FirewallEndpointResolver {
    static func targetPort(
        direction: NETrafficDirection,
        localPort: String,
        remotePort: String
    ) -> String {
        switch direction {
        case .outbound:
            return remotePort
        case .inbound, .any:
            return localPort
        @unknown default:
            return remotePort
        }
    }
}

extension NEFilterFlow {
    /// Get local port
    public func getLocalPort() -> String {
        guard let socketFlow = self as? NEFilterSocketFlow else {
            return ""
        }

        guard #available(macOS 15.0, *) else { return "" }
        guard let endpoint = socketFlow.localFlowEndpoint else { return "" }
        switch endpoint {
        case .hostPort(_, let port):
            return String(describing: port)
        default:
            return ""
        }
    }

    /// Get remote (target) port
    public func getRemotePort() -> String {
        guard let socketFlow = self as? NEFilterSocketFlow else {
            return ""
        }

        guard #available(macOS 15.0, *) else { return "" }
        guard let endpoint = socketFlow.remoteFlowEndpoint else { return "" }
        switch endpoint {
        case .hostPort(_, let port):
            return String(describing: port)
        default:
            return ""
        }
    }

    /// 与 `getHostname()` 配对的目标端口。
    ///
    /// outbound 连接的目标端口在 `remoteFlowEndpoint`；inbound 连接的服务端口
    /// 在 `localFlowEndpoint`。二者不能混用，否则会把客户端的临时源端口显示成
    /// 远程服务端口。
    public func getTargetPort() -> String {
        FirewallEndpointResolver.targetPort(
            direction: direction,
            localPort: getLocalPort(),
            remotePort: getRemotePort()
        )
    }

    /// Get hostname
    public func getHostname() -> String {
        guard let socketFlow = self as? NEFilterSocketFlow else {
            return ""
        }

        guard #available(macOS 15.0, *) else { return "" }
        guard let endpoint = socketFlow.remoteFlowEndpoint else { return "" }
        switch endpoint {
        case .hostPort(let host, _):
            return String(describing: host)
        default:
            return ""
        }
    }

    /// Get App ID
    public func getAppId() -> String {
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

    public func getAppUniqueId() -> String {
        return ""
    }
}
