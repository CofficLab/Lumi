import Foundation

// MARK: - Network Speed Formatting Extensions

extension Double {
    /// 格式化网络速度为人类可读的字符串
    /// - Returns: 格式化后的网速字符串，如 "500 KB/s", "2.5 MB/s"
    func formattedNetworkSpeed() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(self)) + "/s"
    }

    /// 格式化网络流量（不包含 /s 后缀）
    /// - Returns: 格式化后的流量字符串，如 "500 KB", "2.5 MB"
    func formattedBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(self))
    }
}

extension Int64 {
    /// 格式化网络速度为人类可读的字符串
    /// - Returns: 格式化后的网速字符串，如 "500 KB/s", "2.5 MB/s"
    func formattedNetworkSpeed() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: self) + "/s"
    }

    /// 格式化网络流量（不包含 /s 后缀）
    /// - Returns: 格式化后的流量字符串，如 "500 KB", "2.5 MB"
    func formattedBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - Usage Examples

/*
 使用示例：

 // Double 类型网速
 let downloadSpeed: Double = 1024 * 500
 print(downloadSpeed.formattedNetworkSpeed())  // "500 KB/s"

 let uploadSpeed: Double = 1024 * 1024 * 2.5
 print(uploadSpeed.formattedNetworkSpeed())   // "2.5 MB/s"

 // Int64 类型网速
 let speed: Int64 = 1024 * 1024
 print(speed.formattedNetworkSpeed())        // "1 MB/s"

 // 格式化流量（不含 /s）
 let totalDownload: Double = 1024 * 1024 * 100
 print(totalDownload.formattedBytes())        // "100 MB"
 */
