import Foundation
import LumiKernel

enum AppStoreConnectToolSupport {
    static func makeClient() -> (client: ConnectClient?, errorMessage: String?) {
        let credentialStore = CredentialStore.shared
        let credentials = credentialStore.load()
        guard credentials.isComplete else {
            return (nil, "App Store Connect credentials are incomplete. Configure issuer ID, key ID, and private key in the App Store plugin settings first.")
        }
        return (ConnectClient(credentialsProvider: { credentialStore.load() }), nil)
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
