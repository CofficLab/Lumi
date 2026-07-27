import Foundation

// MARK: - Storage Capability Protocol

/// 存储能力协议 - 核心存储接口
///
/// 定义 LumiCore 需要的存储功能，由具体实现包（如 LumiCoreStorage）提供。
@MainActor
public protocol StorageProviding: AnyObject {
    /// 数据根目录
    var dataRootDirectory: URL { get }

    /// 插件数据目录
    func pluginDataDirectory(for pluginID: String) -> URL

    /// 核心数据目录
    func coreDataDirectory() -> URL
}