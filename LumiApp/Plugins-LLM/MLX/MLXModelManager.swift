import Foundation
import Combine
import MagicKit
import os

// Forward reference to MLXModels from MLXModels.swift
private typealias _MLXModels = MLXModels

/// MLX 模型管理器
///
/// 负责：
/// - 管理推荐模型列表
/// - 扫描本地缓存目录，识别已下载模型
/// - 计算缓存大小
/// - 删除模型
///
/// 使用 Combine 发布事件，UI 可以订阅变化。
public final class MLXModelManager: ObservableObject, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.mlx")
    nonisolated public static let emoji = "📦"
    nonisolated public static let verbose = true

    // MARK: - Published Properties

    /// 已缓存的模型 ID 列表
    @Published public private(set) var cachedModelIds: Set<String> = []

    /// 正在下载的模型 ID
    @Published public private(set) var downloadingModelIds: Set<String> = []

    /// 缓存总大小（字节）
    @Published public private(set) var totalCacheSize: Int64 = 0

    /// 系统 RAM（GB）
    @Published public private(set) var systemRAM: Int

    // MARK: - Properties

    private let fileManager: FileManager
    private let cacheDirectory: URL
    private var monitoringTimer: Timer?

    // MARK: - Initialization

    public init() {
        self.fileManager = FileManager.default
        self.cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("models", isDirectory: true)
        self.systemRAM = _MLXModels.detectSystemRAM()

        if Self.verbose {
            Self.logger.info("\(self.t) MLXModelManager 已初始化，系统 RAM: \(self.systemRAM)GB")
        }

        // 确保缓存目录存在
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // 刷新缓存状态
        self.refreshCachedModels()
        self.updateCacheSize()

        // 启动缓存监控（每 5 秒刷新一次）
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// 获取可用的模型列表（根据 RAM 过滤）
    public func availableModels() -> [LocalModelInfo] {
        _MLXModels.availableModels(for: self.systemRAM)
    }

    /// 刷新已缓存的模型列表（定时器每 5 秒调用，用于发现外部下载/删除的模型）
    public func refreshCachedModels() {
        var newIds: Set<String> = []
        for model in _MLXModels.recommended {
            if _MLXModels.isModelCached(id: model.id) {
                newIds.insert(model.id)
            }
        }
        let changed = newIds != self.cachedModelIds
        self.cachedModelIds = newIds
        if Self.verbose, changed {
            Self.logger.info("\(self.t) 刷新缓存模型：\(self.cachedModelIds.count) 个")
        }
    }

    /// 检查模型是否已缓存
    public func isModelCached(id: String) -> Bool {
        cachedModelIds.contains(id)
    }

    /// 检查模型是否正在下载
    public func isModelDownloading(id: String) -> Bool {
        downloadingModelIds.contains(id)
    }

    /// 获取模型状态
    public func getModelState(id: String) -> ModelState {
        if downloadingModelIds.contains(id) {
            return .downloading
        } else if cachedModelIds.contains(id) {
            return .cached
        } else {
            return .notCached
        }
    }

    /// 更新缓存大小
    public func updateCacheSize() {
        totalCacheSize = calculateCacheSize()
    }

    /// 计算缓存大小
    public func calculateCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let size = values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    /// 获取格式化后的缓存大小
    public var formattedCacheSize: String {
        formatBytes(totalCacheSize)
    }

    /// 删除模型
    public func deleteModel(id: String) throws {
        let modelDir = _MLXModels.cacheDirectory(for: id)

        guard fileManager.fileExists(atPath: modelDir.path) else {
            if Self.verbose {
                Self.logger.info("\(self.t) 模型目录不存在：\(id)")
            }
            return
        }

        try fileManager.removeItem(at: modelDir)

        self.cachedModelIds.remove(id)
        self.updateCacheSize()

        if Self.verbose {
            Self.logger.info("\(self.t) 已删除模型：\(id)")
        }
    }

    /// 清空所有缓存
    public func clearAllCache() throws {
        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return
        }

        try fileManager.removeItem(at: cacheDirectory)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        cachedModelIds.removeAll()
        updateCacheSize()

        if Self.verbose {
            Self.logger.info("\(self.t) 已清空所有缓存")
        }
    }

    /// 获取单个模型的缓存大小
    public func getCacheSize(for modelId: String) -> Int64 {
        let modelDir = _MLXModels.cacheDirectory(for: modelId)
        return calculateDirectorySize(at: modelDir)
    }

    /// 获取格式化后的模型大小
    public func formattedSize(for modelId: String) -> String {
        let size = getCacheSize(for: modelId)
        return formatBytes(size)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        stopMonitoring()

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshCachedModels()
            self?.updateCacheSize()
        }

        monitoringTimer?.tolerance = 1.0
    }

    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    // MARK: - Helper Methods

    /// 计算目录大小
    private func calculateDirectorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let size = values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    /// 格式化字节大小
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024

        if bytes >= gb {
            return String(format: "%.2f GB", Double(bytes) / Double(gb))
        } else if bytes >= mb {
            return String(format: "%.2f MB", Double(bytes) / Double(mb))
        } else if bytes >= kb {
            return String(format: "%.2f KB", Double(bytes) / Double(kb))
        } else {
            return "\(bytes) bytes"
        }
    }
}

// MARK: - Model State

/// 模型状态
public enum ModelState: Equatable {
    case notCached
    case downloading
    case cached
}
