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
