import Foundation
import LumiKernel

/// 存储服务提供者
///
/// 实现 CoreServiceProvider 协议，
/// 为 LumiKernel 提供 Storage 功能。
@MainActor
public final class StorageServiceProvider: CoreServiceProvider {

    // MARK: - Properties

    private let storageService: StorageService

    // MARK: - Initialization

    public init(dataRootDirectory: URL) throws {
        self.storageService = try StorageService(dataRootDirectory: dataRootDirectory)
    }

    // MARK: - CoreServiceProvider

    public var storage: (any StorageProviding)? {
        storageService
    }

    // 其他服务使用默认实现（返回 nil）
}