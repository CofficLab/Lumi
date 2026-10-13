import Foundation

public struct InputRule: Identifiable, Codable, Hashable {
    public var id: String { appBundleID }
    public let appBundleID: String
    public let appName: String
    public let inputSourceID: String
}

public struct InputConfig: Codable {
    public var rules: [InputRule] = []
    public var defaultInputSourceID: String?
    public var isEnabled: Bool = true
}
