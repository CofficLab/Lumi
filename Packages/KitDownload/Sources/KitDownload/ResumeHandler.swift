import Foundation

/// 断点续传处理器
public actor ResumeHandler {
    private let fileManager = FileManager.default
    private var resumeDataStore: [URL: Data] = [:]
    
    public init() {}
    
    /// 保存断点续传数据
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - data: 断点续传数据
    public func saveResumeData(for url: URL, data: Data) {
        resumeDataStore[url] = data
    }
    
    /// 获取断点续传数据
    /// - Parameter url: 文件 URL
    /// - Returns: 断点续传数据
    public func getResumeData(for url: URL) -> Data? {
        return resumeDataStore[url]
    }
    
    /// 移除断点续传数据
    /// - Parameter url: 文件 URL
    public func removeResumeData(for url: URL) {
        resumeDataStore.removeValue(forKey: url)
    }
    
    /// 获取已下载的部分文件大小
    /// - Parameter incompleteURL: 未完成文件的路径
    /// - Returns: 已下载的字节数
    public func getPartialFileSize(at incompleteURL: URL) -> Int64 {
        guard fileManager.fileExists(atPath: incompleteURL.path) else {
            return 0
        }
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: incompleteURL.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        
        return size
    }
    
    /// 追加下载的数据到未完成文件
    /// - Parameters:
    ///   - newData: 新下载的数据
    ///   - incompleteURL: 未完成文件的路径
    public func appendData(_ newData: Data, to incompleteURL: URL) throws {
        let fileManager = FileManager.default
        
        // 确保目录存在
        let directory = incompleteURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 如果文件不存在，创建新文件
        if !fileManager.fileExists(atPath: incompleteURL.path) {
            try newData.write(to: incompleteURL)
            return
        }
        
        // 追加数据
        let fileHandle = try FileHandle(forWritingTo: incompleteURL)
        defer { try? fileHandle.close() }
        
        try fileHandle.seekToEnd()
        try fileHandle.write(contentsOf: newData)
    }
    
    /// 将未完成文件重命名为最终文件
    /// - Parameters:
    ///   - incompleteURL: 未完成文件的路径
    ///   - finalURL: 最终文件的路径
    public func finalizeDownload(from incompleteURL: URL, to finalURL: URL) throws {
        let fileManager = FileManager.default

        // 先校验源文件：源缺失时直接抛错，绝不触碰已存在的最终文件（issue #160）。
        guard fileManager.fileExists(atPath: incompleteURL.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: incompleteURL.path])
        }

        if fileManager.fileExists(atPath: finalURL.path) {
            // 原子替换：替换失败时保留原有最终文件，避免「先删后移」在移动失败时毁掉旧结果（issue #160）。
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: incompleteURL)
        } else {
            try fileManager.moveItem(at: incompleteURL, to: finalURL)
        }

        // 清理断点续传数据
        removeResumeData(for: finalURL)
    }
}
