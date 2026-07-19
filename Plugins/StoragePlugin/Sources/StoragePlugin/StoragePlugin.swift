import Foundation
import LumiKernel
import SuperLogKit
import os

/// 存储插件
///
/// 向 LumiKernel 注册 Storage 服务。
@MainActor
public final class StoragePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.storage")
    nonisolated public static let emoji = "💾"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.storage"
    public let name = "Storage Plugin"

    /// 数据根目录
    private let dataRootDirectory: URL

    // MARK: - Initialization

    public init(dataRootDirectory: URL? = nil) throws {
        if let dataRootDirectory {
            self.dataRootDirectory = dataRootDirectory
        } else {
            self.dataRootDirectory = try Self.makeDefaultDataRootDirectory()
        }
    }

    /// 使用默认目录创建
    public convenience init() throws {
        try self.init(dataRootDirectory: nil)
    }

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let storage = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.registerStorage(storage)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Storage 服务: \(self.dataRootDirectory.path)")
        }
    }

    // MARK: - Factory Methods

    private static func makeDefaultDataRootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dataRoot = appSupport.appendingPathComponent("Lumi", isDirectory: true)
        try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        return dataRoot
    }
}
