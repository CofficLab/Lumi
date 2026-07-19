import Foundation
import LumiKernel

/// 存储服务提供者
///
/// 这个类实现了 CoreServiceProvider 协议，
/// 专门提供 Storage 功能。
@MainActor
public final class StorageServiceProvider: CoreServiceProvider {

    // MARK: - Properties

    private let storageService: StorageService

    // MARK: - Initialization

    public init(dataRootDirectory: URL) {
        self.storageService = StorageService(dataRootDirectory: dataRootDirectory)
    }

    // MARK: - CoreServiceProvider

    public var storage: (any StorageProviding)? {
        storageService
    }

    // 其他服务返回 nil（使用默认实现）
}