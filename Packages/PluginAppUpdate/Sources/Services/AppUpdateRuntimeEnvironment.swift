import Foundation

/// The only distribution flag the updater needs. Kept in the host-owned V2
/// package so update checks no longer retain a dependency on `KernelLumi`.
struct AppUpdateRuntimeEnvironment {
    static var current: Self { Self() }

    var allowsAppUpdates: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "LumiAllowsAppUpdates")
        if let value = value as? Bool { return value }
        if let value = value as? String {
            switch value.lowercased() {
            case "yes", "true", "1": return true
            case "no", "false", "0": return false
            default: break
            }
        }
        let identifier = Bundle.main.bundleIdentifier ?? ""
        return !identifier.hasPrefix("com.coffic.lumi.debug")
    }
}
