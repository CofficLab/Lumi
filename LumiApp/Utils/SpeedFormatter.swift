import Foundation

/// 状态栏网速格式化工具
/// 提供紧凑的网速格式化，适用于状态栏小空间显示
struct SpeedFormatter {

    /// 格式化网速用于状态栏显示
    /// - Parameter bytesPerSecond: 字节数/秒
    /// - Returns: 格式化后的字符串，如 "1.2GB/s", "500KB/s", "123B/s"
    static func formatForStatusBar(_ bytesPerSecond: Double) -> String {
        let gb = bytesPerSecond / (1024 * 1024 * 1024)
        let mb = bytesPerSecond / (1024 * 1024)
        let kb = bytesPerSecond / 1024

        if gb >= 1 {
            return String(format: "%.1fGB/s", gb)
        } else if mb >= 1 {
            return String(format: "%.1fMB/s", mb)
        } else if kb >= 1 {
            return String(format: "%.0fKB/s", kb)
        } else {
            return String(format: "%.0fB/s", bytesPerSecond)
        }
    }

    /// 计算格式化后文本的预估宽度（用于动态状态栏宽度）
    /// - Parameter formattedSpeed: 格式化后的速度字符串
    /// - Returns: 预估宽度（点）
    static func estimatedWidth(for formattedSpeed: String) -> CGFloat {
        // 每个字符约 6 点（使用系统字体 10pt）
        // 加上箭头图标约 8 点
        return CGFloat(formattedSpeed.count) * 6 + 8
    }

    /// 计算完整状态栏显示的预估宽度
    /// - Parameters:
    ///   - uploadSpeed: 上传速度
    ///   - downloadSpeed: 下载速度
    /// - Returns: 预估总宽度
    static func estimatedTotalWidth(uploadSpeed: Double, downloadSpeed: Double) -> CGFloat {
        let uploadText = formatForStatusBar(uploadSpeed)
        let downloadText = formatForStatusBar(downloadSpeed)

        // Logo 宽度 + 上传部分 + 间距 + 下载部分 + 边距
        let logoWidth: CGFloat = 20
        let uploadWidth = estimatedWidth(for: uploadText)
        let downloadWidth = estimatedWidth(for: downloadText)
        let spacing: CGFloat = 4
        let padding: CGFloat = 8

        return logoWidth + uploadWidth + spacing + downloadWidth + padding
    }
}
