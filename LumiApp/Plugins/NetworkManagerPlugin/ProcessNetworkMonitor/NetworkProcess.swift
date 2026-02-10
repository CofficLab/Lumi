import Foundation
import AppKit

/// Network process information model
struct NetworkProcess: Identifiable, Equatable {
    let id: Int // PID
    let name: String
    let icon: NSImage?
    var downloadSpeed: Double // Bytes/s
    var uploadSpeed: Double // Bytes/s
    let timestamp: Date
    
    // Helper properties for sorting and display
    var totalSpeed: Double { downloadSpeed + uploadSpeed }

    // Formatted output
    var formattedDownload: String { downloadSpeed.formattedNetworkSpeed() }
    var formattedUpload: String { uploadSpeed.formattedNetworkSpeed() }
    var formattedTotal: String { totalSpeed.formattedNetworkSpeed() }

    static func == (lhs: NetworkProcess, rhs: NetworkProcess) -> Bool {
        return lhs.id == rhs.id && lhs.downloadSpeed == rhs.downloadSpeed && lhs.uploadSpeed == rhs.uploadSpeed
    }
}
