import Foundation
import MagicKit
import CommonCrypto
import os

/// 模型偏好设置本地存储
///
/// 存储策略：
/// - 每个项目有独立的配置文件
/// - 文件路径：~/Library/Application Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/<项目路径哈希>/preference.plist
/// - 使用二进制 plist 格式，原子写入确保数据完整性
final class ModelPreferenceStore: @unchecked Sendable, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "💾" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { ModelPreferencePlugin.verbose }
    /// 专用 Logger - 使用 ModelPreferencePlugin 的 logger
    nonisolated static var logger: Logger { ModelPreferencePlugin.logger }
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ModelPreferenceStore.queue", qos: .userInitiated)
    private let baseDirectory: URL

    static let shared = ModelPreferenceStore()

    private init() {
        // 基础目录：.../db_debug/ModelPreference/projects/
        self.baseDirectory = AppConfig.getDBFolderURL()
            .appendingPathComponent("ModelPreference", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
        
        // 确保基础目录存在
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API (Project-based)

    /// 保存当前项目的模型偏好
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - provider: 供应商名称
    ///   - model: 模型名称
    func savePreference(forProject projectPath: String, provider: String, model: String) {
        queue.sync {
            let fileURL = getFileURL(forProject: projectPath)
            var dict = readDict(from: fileURL)
            
            dict["provider"] = provider
            dict["model"] = model
            dict["lastUpdated"] = Date()
            
            writeDict(dict, to: fileURL)
            
            if Self.verbose {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                Self.logger.info("\(Self.t)保存项目偏好：\(projectName) -> \(provider) / \(model)")
            }
        }
    }

    /// 获取指定项目的模型偏好
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 包含供应商和模型的元组，如果不存在则返回 nil
    func getPreference(forProject projectPath: String) -> (provider: String, model: String, lastUpdated: Date?)? {
        queue.sync {
            let fileURL = getFileURL(forProject: projectPath)
            
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let dict = plist as? [String: Any],
                  let provider = dict["provider"] as? String,
                  let model = dict["model"] as? String else {
                return nil
            }
            
            let lastUpdated = dict["lastUpdated"] as? Date
            
            if Self.verbose {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                Self.logger.info("\(Self.t)读取项目偏好：\(projectName) -> \(provider) / \(model)")
            }
            
            return (provider, model, lastUpdated)
        }
    }

    /// 清除指定项目的模型偏好
    /// - Parameter projectPath: 项目根目录路径
    func clearPreference(forProject projectPath: String) {
        queue.sync {
            let fileURL = getFileURL(forProject: projectPath)
            
            do {
                try fileManager.removeItem(at: fileURL)
                if Self.verbose {
                    let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                    Self.logger.info("\(Self.t)清除项目偏好：\(projectName)")
                }
            } catch {
                Self.logger.error("\(Self.t)❌ 清除项目偏好失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Deprecated (保持向后兼容)

    /// 保存偏好（不指定项目，用于旧版本兼容）
    @available(*, deprecated, message: "请使用 savePreference(forProject:provider:model:)")
    func set(_ value: Any?, forKey key: String) {
        // 使用一个虚拟的全局项目路径
        let globalProjectPath = "__global__"
        let fileURL = getFileURL(forProject: globalProjectPath)
        
        queue.sync {
            var dict = readDict(from: fileURL)
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict, to: fileURL)
        }
    }

    /// 获取值（不指定项目，用于旧版本兼容）
    @available(*, deprecated, message: "请使用 getPreference(forProject:)")
    func object(forKey key: String) -> Any? {
        let globalProjectPath = "__global__"
        let fileURL = getFileURL(forProject: globalProjectPath)
        
        return queue.sync {
            readDict(from: fileURL)[key]
        }
    }

    // MARK: - Private Helpers

    /// 获取指定项目的配置文件 URL
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 配置文件 URL
    private func getFileURL(forProject projectPath: String) -> URL {
        // 使用项目路径的哈希作为目录名，避免路径中有特殊字符
        let projectHash = projectPath.md5()
        let projectDirectory = baseDirectory.appendingPathComponent(projectHash, isDirectory: true)
        
        // 确保项目目录存在
        try? fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        
        return projectDirectory.appendingPathComponent("preference.plist")
    }

    /// 从文件读取字典
    private func readDict(from url: URL) -> [String: Any] {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// 写入字典到文件（原子操作）
    private func writeDict(_ dict: [String: Any], to url: URL) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            Self.logger.error("\(Self.t)❌ 无法序列化 plist")
            return
        }

        let tmpURL = url.deletingLastPathComponent().appendingPathComponent("preference.tmp")
        
        do {
            // 原子写入临时文件
            try data.write(to: tmpURL, options: .atomic)
            
            // 替换原文件
            if fileManager.fileExists(atPath: url.path) {
                _ = try? fileManager.replaceItemAt(url, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: url)
            }
        } catch {
            Self.logger.error("\(Self.t)❌ 写入偏好文件失败：\(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}

// MARK: - String Extension for MD5

extension String {
    /// 生成 MD5 哈希（用于项目路径到目录名的映射）
    func md5() -> String {
        guard let data = self.data(using: .utf8) else {
            return self
        }
        
        let digest = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: 16)
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
