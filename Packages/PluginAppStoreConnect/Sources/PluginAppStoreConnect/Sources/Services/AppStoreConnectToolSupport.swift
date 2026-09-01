import Foundation
import KitAgentTool
import ProviderNetwork

/// JSON-schema values used by the restored App Store Connect tools.
enum AppStoreConnectToolSchemaValue {
    case string(String)
    case object([String: Self])
    case array([Self])
    case bool(Bool)
    case int(Int)
    case number(Double)
    case null

    var anyValue: Any {
        switch self {
        case .string(let value): return value
        case .object(let values): return values.mapValues(\.anyValue)
        case .array(let values): return values.map(\.anyValue)
        case .bool(let value): return value
        case .int(let value): return value
        case .number(let value): return value
        case .null: return NSNull()
        }
    }

    var dictionaryValue: [String: Any] {
        guard case .object(let values) = self else { return [:] }
        return values.mapValues(\.anyValue)
    }
}

extension ToolArgument {
    var stringValue: String? { value as? String }
    var intValue: Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
    var boolValue: Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes", "y": return true
            case "false", "0", "no", "n": return false
            default: return nil
            }
        }
        return nil
    }
}

enum AppStoreConnectToolSupport {
    private static let networkHolder = AppStoreConnectNetworkHolder()

    static func configure(network: (any NetworkProviding)?) {
        networkHolder.set(network)
    }

    static func makeClient() -> (client: ConnectClient?, errorMessage: String?) {
        let credentialStore = CredentialStore.shared
        let credentials = credentialStore.load()
        guard credentials.isComplete else {
            return (
                nil,
                "App Store Connect credentials are incomplete. Configure issuer ID, key ID, and private key in the App Store Connect plugin settings first."
            )
        }
        guard let network = networkHolder.get() else {
            return (nil, "Network service is unavailable.")
        }
        return (
            ConnectClient(credentialsProvider: { credentialStore.load() }, network: network),
            nil
        )
    }

    static func parseInt(_ value: ToolArgument?) -> Int? {
        value?.intValue
    }

    static func parseBool(_ value: ToolArgument?) -> Bool? {
        value?.boolValue
    }
}

private final class AppStoreConnectNetworkHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var network: (any NetworkProviding)?

    func set(_ network: (any NetworkProviding)?) {
        lock.withLock { self.network = network }
    }

    func get() -> (any NetworkProviding)? {
        lock.withLock { network }
    }
}
