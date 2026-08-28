import Foundation
import NetworkExtension

public struct FirewallEvent: Hashable, Identifiable, Sendable {
    public enum Status: Sendable {
        case allowed
        case rejected
    }
    
    public var id: String = UUID().uuidString
    public var time: Date = Date()
    public var address: String
    public var port: String
    public var sourceAppIdentifier: String = ""
    public var status: Status
    public var direction: NETrafficDirection
    
    public var isAllowed: Bool {
        status == .allowed
    }
    
    public var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: time)
    }
    
    public var description: String {
        "\(address):\(port)"
    }
    
    public var statusDescription: String {
        switch status {
        case .allowed:
            return "Allowed"
        case .rejected:
            return "Blocked"
        }
    }
}
