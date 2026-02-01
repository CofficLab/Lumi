import Foundation

struct InputRule: Identifiable, Codable, Hashable {
    var id: String { appBundleID }
    let appBundleID: String
    let appName: String
    let inputSourceID: String
}

struct InputConfig: Codable {
    var rules: [InputRule] = []
    var defaultInputSourceID: String?
    var isEnabled: Bool = true
}
