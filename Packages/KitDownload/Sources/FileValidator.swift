import Foundation

/// 文件验证器
public struct FileValidator: Sendable {
    public init() {}
    
    /// 验证文件是否存在且大小正确
    /// - Parameters:
    ///   - path: 文件路径
    ///   - expectedSize: 期望的文件大小（可选）
    /// - Returns: 验证结果
    public func validate(
        fileAt path: URL,
        expectedSize: Int64? = nil
    ) throws -> Bool {
        let fileManager = FileManager.default
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: path.path) else {
            throw DownloadError.fileNotFound(path.path)
        }
        
        // 获取文件属性
        let attributes = try fileManager.attributesOfItem(atPath: path.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // 检查文件是否为空
        if fileSize == 0 {
            throw DownloadError.emptyFile(path.path)
        }
        
        // 检查文件大小是否匹配
        if let expectedSize, fileSize != expectedSize {
            throw DownloadError.sizeMismatch(expected: expectedSize, actual: fileSize)
        }
        
        return true
    }
    
    /// 检查文件是否已完整下载
    /// - Parameters:
    ///   - path: 文件路径
    ///   - expectedSize: 期望的文件大小
    /// - Returns: 是否完整
    public func isComplete(
        fileAt path: URL,
        expectedSize: Int64
    ) -> Bool {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path.path) else {
            return false
        }
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: path.path),
              let fileSize = attributes[.size] as? Int64 else {
            return false
        }
        
        return fileSize == expectedSize
    }
}
