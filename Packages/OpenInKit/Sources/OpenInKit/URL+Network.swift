import Foundation

public extension URL {
    /// 是否是网络 URL（http / https）
    var isNetworkURL: Bool {
        scheme == "http" || scheme == "https"
    }
}
