import Foundation
import SwiftUI

struct RelatedFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let path: String
    let size: Int64
    let type: RelatedFileType
    /// 是否能可靠确认该路径属于当前应用。
    ///
    /// 仅凭 `CFBundleName` 同名匹配到的 Application Support 目录无法证明归属
    /// （不同厂商可能共用同一显示名），这类条目置为 false，卸载时不得默认勾选，
    /// 避免误删其它厂商的数据（见 issue #647）。
    let ownershipVerified: Bool

    init(path: String, size: Int64, type: RelatedFileType, ownershipVerified: Bool = true) {
        self.path = path
        self.size = size
        self.type = type
        self.ownershipVerified = ownershipVerified
    }

    var name: String {
        (path as NSString).lastPathComponent
    }

    enum RelatedFileType: String, Codable {
        case app
        case support
        case cache
        case preferences
        case state
        case container
        case log
        case other

        var displayName: String {
            switch self {
            case .app: return "Application"
            case .support: return "Application Support"
            case .cache: return "Caches"
            case .preferences: return "Preferences"
            case .state: return "Saved State"
            case .container: return "Containers"
            case .log: return "Logs"
            case .other: return "Other"
            }
        }
    }
}

