import Foundation

// MARK: - Network Speed Formatting Extensions

extension Double {
    /// 格式化网络速度为人类可读的字符串
    /// - Returns: 格式化后的网速字符串，如 "500 KB/s", "2.5 MB/s", "0 KB/s"
    func formattedNetworkSpeed() -> String {
        // 处理 0 值的情况，避免显示 "Zero KB/s"
        if self == 0 {
            return "0 KB/s"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        var result = formatter.string(fromByteCount: Int64(self))

        // 替换可能出现的 "Zero KB" 为 "0 KB"
        if result.contains("Zero") {
            result = result.replacingOccurrences(of: "Zero", with: "0")
        }

        return result + "/s"
    }

    /// 格式化网络流量（不包含 /s 后缀）
    /// - Returns: 格式化后的流量字符串，如 "500 KB", "2.5 MB", "0 KB"
    func formattedBytes() -> String {
        // 处理 0 值的情况
        if self == 0 {
            return "0 KB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        var result = formatter.string(fromByteCount: Int64(self))

        // 替换可能出现的 "Zero KB" 为 "0 KB"
        if result.contains("Zero") {
            result = result.replacingOccurrences(of: "Zero", with: "0")
        }

        return result
    }
}

extension Int64 {
    /// 格式化网络速度为人类可读的字符串
    /// - Returns: 格式化后的网速字符串，如 "500 KB/s", "2.5 MB/s", "0 KB/s"
    func formattedNetworkSpeed() -> String {
        // 处理 0 值的情况
        if self == 0 {
            return "0 KB/s"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        var result = formatter.string(fromByteCount: self)

        // 替换可能出现的 "Zero KB" 为 "0 KB"
        if result.contains("Zero") {
            result = result.replacingOccurrences(of: "Zero", with: "0")
        }

        return result + "/s"
    }

    /// 格式化网络流量（不包含 /s 后缀）
    /// - Returns: 格式化后的流量字符串，如 "500 KB", "2.5 MB", "0 KB"
    func formattedBytes() -> String {
        // 处理 0 值的情况
        if self == 0 {
            return "0 KB"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        var result = formatter.string(fromByteCount: self)

        // 替换可能出现的 "Zero KB" 为 "0 KB"
        if result.contains("Zero") {
            result = result.replacingOccurrences(of: "Zero", with: "0")
        }

        return result
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
