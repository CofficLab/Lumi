import Foundation

// MARK: - Storage Capability Protocol

/// 存储能力协议 - 核心存储接口
///
/// 定义内核需要的存储功能，由具体实现包提供。
/// 是所有插件往磁盘存储数据的基础：插件通过
/// `pluginDataDirectory(for:)` 获取自己的数据目录。
@MainActor
public protocol StorageProviding: AnyObject {
    /// 数据根目录
    var dataRootDirectory: URL { get }

    /// 插件数据目录
    func pluginDataDirectory(for pluginID: String) -> URL

    /// 核心数据目录
    func coreDataDirectory() -> URL

    /// 异步计算数据根目录实际占用的磁盘空间（字节）。
    func dataRootDirectorySizeInBytes() async -> Int64
}

public extension StorageProviding {
    /// 默认实现放在 ProviderStorage 中，避免各个 StorageProviding 实现重复处理文件遍历。
    /// 文件扫描在 utility 优先级的后台任务执行，不阻塞设置页面的主线程。
    func dataRootDirectorySizeInBytes() async -> Int64 {
        let rootPath = dataRootDirectory.path
        return await Task.detached(priority: .utility) {
            StorageDirectorySizeCalculator.calculate(atPath: rootPath)
        }.value
    }
}

private enum StorageDirectorySizeCalculator {
    static func calculate(atPath path: String) -> Int64 {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else {
                continue
            }

            let size = Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
            total = total.addingReportingOverflow(size).overflow
                ? Int64.max
                : total + size
        }
        return total
    }
}
