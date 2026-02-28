import Foundation

enum RegistryType: String, CaseIterable, Identifiable {
    case npm
    case yarn
    case pnpm
    case docker
    case pip
    case go
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .npm: return "NPM"
        case .yarn: return "Yarn"
        case .pnpm: return "PNPM"
        case .docker: return "Docker"
        case .pip: return "Pip"
        case .go: return "Go Proxy"
        }
    }
    
    var icon: String {
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

struct RegistrySource: Identifiable, Hashable {
    var id: String { url }
    let name: String
    let url: String
    let type: RegistryType
}

struct RegistryStatus {
    var currentRegistry: String?
    var isChecking: Bool = false
    var error: String?
}
