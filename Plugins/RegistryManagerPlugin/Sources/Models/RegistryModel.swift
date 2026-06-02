import Foundation

public enum RegistryType: String, CaseIterable, Identifiable, Sendable {
    case npm
    case yarn
    case pnpm
    case docker
    case pip
    case go
    
    public var id: String { rawValue }
    
    public var name: String {
        switch self {
        case .npm: return "NPM"
        case .yarn: return "Yarn"
        case .pnpm: return "PNPM"
        case .docker: return "Docker"
        case .pip: return "Pip"
        case .go: return "Go Proxy"
        }
    }
    
    public var icon: String {
        switch self {
        case .npm: return "hexagon"
        case .yarn: return "shippingbox.fill" // Yarn logo is a cat/ball of yarn, but shippingbox is generic
        case .pnpm: return "bolt.fill"
        case .docker: return "shippingbox"
        case .pip: return "ladybug" // Python logo snake... ladybug for now or terminal
        case .go: return "g.circle"
        }
    }
}

public struct RegistrySource: Identifiable, Hashable, Sendable {
    public var id: String { url }
    public let name: String
    public let url: String
    public let type: RegistryType
}

public struct RegistryStatus: Sendable {
    public var currentRegistry: String?
    public var isChecking: Bool = false
    public var error: String?
}
