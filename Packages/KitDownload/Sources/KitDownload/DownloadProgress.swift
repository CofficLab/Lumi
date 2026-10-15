import Foundation

/// 下载进度信息
public struct DownloadProgress: Sendable, Equatable {
    /// 已下载的字节数
    public let downloadedBytes: Int64
    /// 总字节数（如果已知）
    public let totalBytes: Int64?
    /// 已下载的文件数
    public let downloadedFiles: Int
    /// 总文件数
    public let totalFiles: Int
    /// 下载速度（字节/秒）
    public let bytesPerSecond: Double?
    
    public init(
        downloadedBytes: Int64 = 0,
        totalBytes: Int64? = nil,
        downloadedFiles: Int = 0,
        totalFiles: Int = 0,
        bytesPerSecond: Double? = nil
    ) {
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.downloadedFiles = downloadedFiles
        self.totalFiles = totalFiles
        self.bytesPerSecond = bytesPerSecond
    }
    
    /// 下载进度百分比（0.0 - 1.0）
    public var fractionCompleted: Double {
        guard let totalBytes, totalBytes > 0 else {
            return 0.0
        }
        return Double(downloadedBytes) / Double(totalBytes)
    }
    
    /// 进度百分比字符串
    public var percentLabel: String {
        "\(Int(fractionCompleted * 100))%"
    }
    
    /// 下载速度标签
    public var speedLabel: String {
        guard let bytesPerSecond, bytesPerSecond > 0 else {
            return ""
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
}
