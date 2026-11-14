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

        // 大小匹配是权威判据，必须先于任何「空文件」判断：期望 0 字节且实际
        // 0 字节是合法下载，旧实现先抛 emptyFile 会让 expectedSize == 0 永远无法通过（#159）。
        if let expectedSize {
            guard fileSize == expectedSize else {
                throw DownloadError.sizeMismatch(expected: expectedSize, actual: fileSize)
            }
            return true
        }

        // 无期望大小时：validate 仅在 HTTP 200/206 成功返回后调用（非 2xx 与连接
        // 中断都已在 HTTPClient 上游抛出，替换下载另有 written/Content-Length 校验），
        // 干净返回的零字节是合法资源（空文本、占位文件、Content-Length: 0），
        // 不得一律判为 emptyFile 失败（#159）。
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
