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

    // 格式化输出（使用扩展方法）
    var formattedDownload: String { downloadSpeed.formattedNetworkSpeed() }
    var formattedUpload: String { uploadSpeed.formattedNetworkSpeed() }
    var formattedTotal: String { totalSpeed.formattedNetworkSpeed() }

    static func == (lhs: NetworkProcess, rhs: NetworkProcess) -> Bool {
        return lhs.id == rhs.id && lhs.downloadSpeed == rhs.downloadSpeed && lhs.uploadSpeed == rhs.uploadSpeed
    }
}
