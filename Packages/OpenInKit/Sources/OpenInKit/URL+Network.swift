import Foundation

public extension URL {
    /// 是否是网络 URL（http / https）
    var isNetworkURL: Bool {
        let normalizedScheme = scheme?.lowercased()
        return normalizedScheme == "http" || normalizedScheme == "https"
    }
}
