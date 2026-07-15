import Foundation
import Darwin
import LumiCoreKit

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
        Gemma4Models.all +
        CoderModels.all +
        DeepSeekModels.all +
        MicrosoftModels.all

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

    /// 检查模型是否已缓存（完整下载完成）
    ///
    /// 校验目录存在且实际占用大小达到模型期望大小（`expectedBytes`）。
    /// 不再用「safetensors ≥1MB」作为判据——下载中途的部分文件轻松超过该阈值，
    /// 会导致下载中被误判为已缓存，UI 按钮错乱（暂停按钮变加载按钮）。
    public static func isModelCached(id: String) -> Bool {
        let cacheDir = cacheDirectory(for: id)
        guard FileManager.default.fileExists(atPath: cacheDir.path) else { return false }

        // tokenizer.json 是 swift-transformers 的硬性要求，缺失即说明下载未完成或损坏
        guard fileExistsNonEmpty(cacheDir.appendingPathComponent("tokenizer.json")) else { return false }

        // 取模型期望大小；若清单缺失该模型或无 expectedBytes，退回到 safetensors 有效性检查
        guard let model = model(id: id), model.expectedBytes > 0 else {
            return containsValidSafetensorsFiles(cacheDir)
        }

        let expectedBytes = Int64(model.expectedBytes)
        let actualSize = directorySize(at: cacheDir)
        // 实际大小达到期望大小（允许略小以容忍文件系统开销误差）才算完整缓存。
        // 下载中途的目录大小远小于 expectedBytes，因此不会误判为已缓存。
        return actualSize >= Int64(Double(expectedBytes) * 0.99)
    }

    // MARK: - 缓存管理

    /// 所有 MLX 模型的缓存根目录
    public static var modelsCacheBaseDirectory: URL {
        cacheRootDirectory.appendingPathComponent("models", isDirectory: true)
    }

    /// 获取模型缓存目录
    public static func cacheDirectory(for modelId: String) -> URL {
        cachePathComponents(for: modelId).reduce(modelsCacheBaseDirectory) { url, component in
            url.appendingPathComponent(component, isDirectory: true)
        }
    }

    private static var cacheRootDirectory: URL {
        lumiCorePluginDataDirectory(for: "LLMProviderMLX")
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent("LLMProviderMLX", isDirectory: true)
    }

    private static func cachePathComponents(for modelId: String) -> [String] {
        let components = modelId.split(separator: "/").map { sanitizedCachePathComponent(String($0)) }
        if components.count >= 2 {
            return Array(components.prefix(2))
        }
        return [sanitizedCachePathComponent(modelId)]
    }

    private static func sanitizedCachePathComponent(_ component: String) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return "_" }
        return trimmed
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    /// 计算目录下所有文件的总大小（字节），用于缓存完整性校验。
    private static func directorySize(at directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
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
        return totalSize
    }

    /// 检查文件是否存在且非空
    private static func fileExistsNonEmpty(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return false }
        return size > 0
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
