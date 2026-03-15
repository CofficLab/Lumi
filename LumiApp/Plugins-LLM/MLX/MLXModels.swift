import Foundation
import Darwin

/// MLX 本地模型信息
///
/// 包含模型的基本信息、大小要求和功能特性。
public struct MLXModelInfo: Identifiable, Equatable, Sendable {
    /// 模型唯一标识符（HuggingFace ID）
    public let id: String

    /// 显示名称
    public let name: String

    /// 模型描述
    public let description: String

    /// 文件大小（人类可读）
    public let size: String

    /// 最小内存要求（GB）
    public let minRAM: Int

    /// 预期下载字节数
    public let expectedBytes: Int64

    /// 是否支持视觉输入（VLM）
    public let supportsVision: Bool

    /// 是否支持工具调用
    public let supportsTools: Bool

    /// 推荐优先级（越小越推荐）
    public let priority: Int

    public init(
        id: String,
        name: String,
        description: String = "",
        size: String,
        minRAM: Int,
        expectedBytes: Int64,
        supportsVision: Bool = false,
        supportsTools: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.size = size
        self.minRAM = minRAM
        self.expectedBytes = expectedBytes
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.priority = priority
    }
}

/// MLX 推荐模型列表
///
/// 按内存要求分类，提供适合不同设备的模型选择。
public enum MLXModels {

    // MARK: - 推荐模型（按优先级排序）

    /// 所有推荐模型（按 priority 排序）
    public static let recommended: [MLXModelInfo] = [
        // Qwen 系列 - 中文友好，性价比高
        MLXModelInfo(
            id: "mlx-community/Qwen3.5-9B-4bit",
            name: "Qwen 3.5 9B",
            description: "阿里云最新模型，中文能力强，支持工具调用",
            size: "~6 GB",
            minRAM: 16,
            expectedBytes: 6_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 1
        ),
        MLXModelInfo(
            id: "mlx-community/Qwen3.5-14B-4bit",
            name: "Qwen 3.5 14B",
            description: "更强的中文模型，适合复杂任务",
            size: "~9 GB",
            minRAM: 24,
            expectedBytes: 9_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 2
        ),

        // Mistral 系列 - 轻量高效
        MLXModelInfo(
            id: "mlx-community/Mistral-Nemo-12B-Instruct-4bit",
            name: "Mistral Nemo 12B",
            description: "轻量高效，适合日常使用",
            size: "~7 GB",
            minRAM: 16,
            expectedBytes: 7_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 3
        ),

        // Llama 系列 - 通用能力强
        MLXModelInfo(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B",
            description: "超轻量，适合低配置设备",
            size: "~2 GB",
            minRAM: 8,
            expectedBytes: 2_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 4
        ),
        MLXModelInfo(
            id: "mlx-community/Llama-3.3-70B-Instruct-4bit",
            name: "Llama 3.3 70B",
            description: "最强开源模型，需要高配置",
            size: "~40 GB",
            minRAM: 64,
            expectedBytes: 40_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 5
        ),

        // VLM 视觉模型
        MLXModelInfo(
            id: "mlx-community/Qwen2-VL-7B-Instruct-4bit",
            name: "Qwen2 VL 7B",
            description: "支持图片理解的视觉语言模型",
            size: "~5 GB",
            minRAM: 16,
            expectedBytes: 5_000_000_000,
            supportsVision: true,
            supportsTools: false,
            priority: 10
        ),
    ]

    // MARK: - 按内存要求过滤

    /// 根据系统 RAM 获取可用模型列表
    /// - Parameter systemRAM: 系统内存（GB），为 nil 时自动检测
    /// - Returns: 可用模型列表（按优先级排序）
    public static func availableModels(for systemRAM: Int? = nil) -> [MLXModelInfo] {
        let ram = systemRAM ?? detectSystemRAM()
        return recommended
            .filter { $0.minRAM <= ram }
            .sorted { $0.priority < $1.priority }
    }

    /// 获取支持视觉的模型
    public static let visionModels: [MLXModelInfo] = recommended.filter { $0.supportsVision }

    /// 获取支持工具调用的模型
    public static let toolModels: [MLXModelInfo] = recommended.filter { $0.supportsTools }

    // MARK: - 按 ID 查找

    /// 根据 ID 查找模型
    public static func model(id: String) -> MLXModelInfo? {
        recommended.first { $0.id == id }
    }

    /// 检查模型是否已缓存
    public static func isModelCached(id: String) -> Bool {
        let cacheDir = cacheDirectory(for: id)
        return FileManager.default.fileExists(atPath: cacheDir.path) && containsValidSafetensorsFiles(cacheDir)
    }

    // MARK: - 缓存管理

    /// 获取模型缓存目录
    public static func cacheDirectory(for modelId: String) -> URL {
        let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let components = modelId.split(separator: "/").map(String.init)
        if components.count >= 2 {
            return cacheBase
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent(components[0], isDirectory: true)
                .appendingPathComponent(components[1], isDirectory: true)
        } else {
            return cacheBase
                .appendingPathComponent("models", isDirectory: true)
                .appendingPathComponent(modelId, isDirectory: true)
        }
    }

    /// 检查目录是否包含有效的 safetensors 文件
    private static func containsValidSafetensorsFiles(_ directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var totalSize: Int64 = 0
        let minValidSize: Int64 = 1_000_000 // 至少 1MB

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "safetensors" else { continue }

            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                guard values.isDirectory != true else { continue }
                if let size = values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }

        return totalSize >= minValidSize
    }

    // MARK: - 系统 RAM 检测

    /// 检测系统 RAM 大小（GB）
    public static func detectSystemRAM() -> Int {
        // 使用 sysctl 获取物理内存
        var mem: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        let result = withUnsafeMutablePointer(to: &mem) {
            $0.withMemoryRebound(to: Int.self, capacity: 1) {
                sysctlbyname("hw.memsize", $0, &len, nil, 0)
            }
        }

        if result == 0 && mem > 0 {
            return Int(mem / (1024 * 1024 * 1024))
        }

        // 降级：如果 sysctl 失败，尝试通过 ProcessInfo
        // 注意：这不太准确，但对于 M 系列芯片通常返回正确值
        return Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
    }
}
