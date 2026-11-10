import Foundation
import AppKit

/// Network process information model
public struct NetworkProcess: Identifiable, Equatable {
    public let id: Int // PID
    public let name: String
    public let icon: NSImage?
    public var downloadSpeed: Double // Bytes/s
    public var uploadSpeed: Double // Bytes/s
    public let timestamp: Date

    /// 同名进程的份数；聚合后大于 1 时界面需标注份数。
    public var instanceCount: Int = 1
    /// 该组是否包含 Lumi 自身进程；界面需单独标注，但不从榜单中排除。
    public var isCurrentApp: Bool = false
    
    // Helper properties for sorting and display
    public var totalSpeed: Double { downloadSpeed + uploadSpeed }

    // Formatted output
    public var formattedDownload: String { downloadSpeed.formattedNetworkSpeed() }
    public var formattedUpload: String { uploadSpeed.formattedNetworkSpeed() }
    public var formattedTotal: String { totalSpeed.formattedNetworkSpeed() }

    public static func == (lhs: NetworkProcess, rhs: NetworkProcess) -> Bool {
        return lhs.id == rhs.id && lhs.downloadSpeed == rhs.downloadSpeed && lhs.uploadSpeed == rhs.uploadSpeed
    }
}
