import Foundation

enum FinderRuntimeEnvironment {
    static let appGroupIdentifier = requiredInfoValue(forKey: "LumiAppGroupIdentifier")
    static let urlScheme = requiredInfoValue(forKey: "LumiURLScheme")

    private static func requiredInfoValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            preconditionFailure("Missing required Finder extension configuration: \(key)")
        }
        return value
    }
}
