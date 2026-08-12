import Foundation
import LumiKernel

enum AppStoreConnectToolSupport {
    private static let networkHolder = AppStoreConnectNetworkHolder()

    static func configure(network: (any NetworkProviding)?) {
        networkHolder.set(network)
    }

    static func makeClient(kernel _: LumiKernel) -> (client: ConnectClient?, errorMessage: String?) {
        let credentialStore = CredentialStore.shared
        let credentials = credentialStore.load()
        guard credentials.isComplete else {
            return (nil, "App Store Connect credentials are incomplete. Configure issuer ID, key ID, and private key in the App Store plugin settings first.")
        }
        guard let network = networkHolder.get() else {
            return (nil, "Network service is unavailable.")
        }
        return (ConnectClient(credentialsProvider: { credentialStore.load() }, network: network), nil)
    }

    static func parseInt(_ value: LumiJSONValue?) -> Int? {
        if case let .int(number)? = value {
            return number
        }
        if case let .string(raw)? = value {
            return Int(raw)
        }
        return nil
    }

    static func parseBool(_ value: LumiJSONValue?) -> Bool? {
        if case let .bool(flag)? = value {
            return flag
        }
        if case let .string(raw)? = value {
            switch raw.lowercased() {
            case "true", "1", "yes", "y": return true
            case "false", "0", "no", "n": return false
            default: return nil
            }
        }
        return nil
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
