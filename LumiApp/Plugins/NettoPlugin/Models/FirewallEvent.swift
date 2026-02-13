import Foundation
import NetworkExtension

struct FirewallEvent: Hashable, Identifiable, Sendable {
    enum Status {
        case allowed
        case rejected
    }
    
    var id: String = UUID().uuidString
    var time: Date = Date()
    var address: String
    var port: String
    var sourceAppIdentifier: String = ""
    var status: Status
    var direction: NETrafficDirection
    
    var isAllowed: Bool {
        status == .allowed
    }
    
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: time)
    }
    
    var description: String {
        "\(address):\(port)"
    }
    
    var statusDescription: String {
        switch status {
        case .allowed:
            return "Allowed"
        case .rejected:
            return "Blocked"
        }
    }
}
