import Foundation

/// Runtime identifiers that must remain consistent across the Lumi app and its extensions.
///
/// Release keeps the historical identifiers so existing data remains available. The Debug app
/// uses a separate namespace for shared containers, URL routing, Keychain services, and updates.
public struct LumiRuntimeEnvironment: Equatable, Sendable {
    public static let productionBundleIdentifier = "com.coffic.lumi"
    public static let debugBundleIdentifier = "com.coffic.lumi.debug"

    public let name: String
    public let bundleIdentifier: String
    public let appGroupIdentifier: String
    public let urlScheme: String
    public let keychainServiceSuffix: String
    public let allowsAppUpdates: Bool

    public var isDebug: Bool { name == "debug" }

    public func keychainService(for productionService: String) -> String {
        productionService + keychainServiceSuffix
    }

    public static var current: Self {
        resolve(
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
    }

    public static func resolve(
        infoDictionary: [String: Any],
        bundleIdentifier: String?
    ) -> Self {
        let resolvedBundleIdentifier = bundleIdentifier ?? productionBundleIdentifier
        let inferredDebug = resolvedBundleIdentifier == debugBundleIdentifier
            || resolvedBundleIdentifier.hasPrefix(debugBundleIdentifier + ".")
        let name = resolvedString(
            infoDictionary["LumiEnvironment"],
            fallback: inferredDebug ? "debug" : "release"
        )
        let isDebug = name == "debug"

        return Self(
            name: name,
            bundleIdentifier: resolvedBundleIdentifier,
            appGroupIdentifier: resolvedString(
                infoDictionary["LumiAppGroupIdentifier"],
                fallback: isDebug ? "group.com.coffic.lumi.debug" : "group.com.coffic.lumi"
            ),
            urlScheme: resolvedString(
                infoDictionary["LumiURLScheme"],
                fallback: isDebug ? "lumi-debug" : "lumi"
            ),
            keychainServiceSuffix: resolvedString(
                infoDictionary["LumiKeychainServiceSuffix"],
                fallback: isDebug ? ".debug" : ""
            ),
            allowsAppUpdates: resolvedBool(
                infoDictionary["LumiAllowsAppUpdates"],
                fallback: !isDebug
            )
        )
    }

    private static func resolvedString(_ value: Any?, fallback: String) -> String {
        guard let value = value as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            return fallback
        }
        return value
    }

    private static func resolvedBool(_ value: Any?, fallback: Bool) -> Bool {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? String {
            switch value.lowercased() {
            case "yes", "true", "1": return true
            case "no", "false", "0": return false
            default: break
            }
        }
        return fallback
    }
}
