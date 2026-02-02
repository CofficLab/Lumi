import Foundation
import AppKit

/// 进程网络信息模型
struct NetworkProcess: Identifiable, Equatable {
    let id: Int // PID
    let name: String
    let icon: NSImage?
    var downloadSpeed: Double // Bytes/s
    var uploadSpeed: Double // Bytes/s
    let timestamp: Date
    
    // 用于排序和显示的辅助属性
    var totalSpeed: Double { downloadSpeed + uploadSpeed }
    
    // 格式化输出
    var formattedDownload: String { ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .memory) + "/s" }
    var formattedUpload: String { ByteCountFormatter.string(fromByteCount: Int64(uploadSpeed), countStyle: .memory) + "/s" }
    var formattedTotal: String { ByteCountFormatter.string(fromByteCount: Int64(totalSpeed), countStyle: .memory) + "/s" }
    
    static func == (lhs: NetworkProcess, rhs: NetworkProcess) -> Bool {
        return lhs.id == rhs.id && lhs.downloadSpeed == rhs.downloadSpeed && lhs.uploadSpeed == rhs.uploadSpeed
    }
}
