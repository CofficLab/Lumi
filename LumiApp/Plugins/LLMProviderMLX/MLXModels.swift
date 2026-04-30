import Foundation
import Darwin

/// MLX 推荐模型列表
///
/// 按内存要求分类，提供适合不同设备的模型选择。
public enum MLXModels {

    // MARK: - 推荐模型（按优先级排序）

    /// 所有推荐模型（按 priority 排序）
    public static let recommended: [LocalModelInfo] = 
        QwenModels.all + 
        MistralModels.all + 
        LlamaModels.all + 
        Gemma4Models.all

    // MARK: - 按内存要求过滤

    /// 根据系统 RAM 获取可用模型列表
    /// - Parameter systemRAM: 系统内存（GB），为 nil 时自动检测
    /// - Returns: 可用模型列表（按优先级排序）
    public static func availableModels(for systemRAM: Int? = nil) -> [LocalModelInfo] {
        let ram = systemRAM ?? detectSystemRAM()
        return recommended
            .filter { $0.minRAM <= ram }
            .sorted { $0.minRAM != $1.minRAM ? $0.minRAM < $1.minRAM : $0.priority < $1.priority }
    }

    /// 获取支持视觉的模型
    public static var visionModels: [LocalModelInfo] { recommended.filter { $0.supportsVision } }

    /// 获取支持工具调用的模型
    public static var toolModels: [LocalModelInfo] { recommended.filter { $0.supportsTools } }

    // MARK: - 按 ID 查找

    /// 根据 ID 查找模型
    public static func model(id: String) -> LocalModelInfo? {
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