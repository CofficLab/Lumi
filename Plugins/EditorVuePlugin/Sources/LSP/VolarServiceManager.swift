import Foundation
import os
import SuperLogKit

/// Volar Language Server 进程生命周期管理器
///
/// 负责 @vue/language-server 的启动配置、进程探测和混合模式管理。
/// 实际的 LSP 进程创建由内核 LSPService 通过 LanguageServer.create 统一处理，
/// 本模块提供配置参数和前置检查。
///
/// **架构定位**：
/// - LSPService 负责实际的进程 fork 和 JSON-RPC 通信
/// - VolarServiceManager 负责 Vue 特有的配置注入和健康检查
/// - VueLanguageIntegrationCapability 负责将两者桥接
struct VolarServiceManager: Sendable, SuperLog {
    nonisolated static let emoji = "🌋"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.volar"
    )

    // MARK: - Volar 配置

    /// Volar 服务配置
    struct VolarConfig: Sendable {
        /// 项目根路径
        let projectPath: String

        /// 检测到的 Vue 版本
        let vueVersion: VueVersionDetector.VueVersion

        /// 是否启用混合模式（推荐）
        let hybridMode: Bool

        /// Node.js 可执行路径
        let nodePath: String

        /// Volar 二进制路径（相对于 node_modules）
        let serverBinary: String

        /// 初始化选项
        var initializationOptions: [String: String] {
            var options: [String: String] = [:]
            options["vue.server.hybridMode"] = hybridMode ? "true" : "false"
            options["vueVersion"] = vueVersion == .vue2 ? "2" : "3"

            if EditorVuePlugin.verbose {
                logger.info("\(VolarServiceManager.t)\(VolarServiceManager.emoji) Volar 初始化选项: \(options)")
            }

            return options
        }

        /// 完整的启动命令
        var launchCommand: String {
            "\(nodePath) \(projectPath)/\(serverBinary) --stdio"
        }
    }

    // MARK: - 服务状态

    /// Volar 服务健康状态
    enum ServiceHealth: Sendable {
        /// 未检测（项目非 Vue 项目）
        case notApplicable
        /// 就绪（node_modules 中存在 Volar）
        case ready(VolarConfig)
        /// Node.js 未安装
        case nodeNotFound
        /// Volar 未安装
        case volarNotFound(nodePath: String)
        /// Vue 依赖缺失
        case vueNotFound
    }

    // MARK: - 公开方法

    /// 检查指定项目的 Volar 服务健康状态
    ///
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 服务健康状态
    static func checkHealth(projectPath: String) -> ServiceHealth {
        // 1. 检查 Node.js
        guard let nodePath = findNodePath() else {
            return .nodeNotFound
        }

        // 2. 检查 Vue 依赖
        let vueVersion = VueVersionDetector.detect(at: projectPath)
        if vueVersion == .unknown {
            // 检查 package.json 是否存在
            let packageJSONPath = (projectPath as NSString).appendingPathComponent("package.json")
            if !FileManager.default.fileExists(atPath: packageJSONPath) {
                return .notApplicable
            }
            return .vueNotFound
        }

        // 3. 检查 Volar 二进制
        let serverBinary = vueVersion.languageServerBinary
        let fullPath = (projectPath as NSString).appendingPathComponent(serverBinary)

        guard FileManager.default.fileExists(atPath: fullPath) else {
            return .volarNotFound(nodePath: nodePath)
        }

        // 4. 构建配置
        let config = VolarConfig(
            projectPath: projectPath,
            vueVersion: vueVersion,
            hybridMode: true, // 默认启用混合模式
            nodePath: nodePath,
            serverBinary: serverBinary
        )

        return .ready(config)
    }

    /// 为 LSPService 生成 Volar 的服务器配置
    ///
    /// 此方法返回的配置会被 VueLanguageIntegrationCapability 消费，
    /// 最终传递给 LanguageServer.create。
    ///
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 服务器配置，如果 Volar 不可用则返回 nil
    static func serverConfig(projectPath: String) -> VolarConfig? {
        guard case .ready(let config) = checkHealth(projectPath: projectPath) else {
            return nil
        }
        return config
    }

    // MARK: - Node.js 探测

    /// Node.js 可能的路径列表（按优先级排序）
    private static let nodeSearchPaths: [String] = {
        var paths: [String] = []

        // 1. 环境 PATH 中的 node
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let pathDirs = pathEnv.split(separator: ":").map(String.init)
            for dir in pathDirs {
                let nodePath = (dir as NSString).appendingPathComponent("node")
                paths.append(nodePath)
            }
        }

        // 2. 常见安装路径
        let commonPaths = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
            "$HOME/.nvm/versions/node/*/bin/node",
            "$HOME/.volta/bin/node",
            "$HOME/.asdf/shims/node",
            "/usr/local/opt/node/bin/node",
        ]
        paths.append(contentsOf: commonPaths)

        return paths
    }()

    /// 查找可用的 Node.js 路径
    ///
    /// - Returns: Node.js 可执行文件路径，未找到返回 nil
    static func findNodePath() -> String? {
        let fm = FileManager.default

        // 展开环境变量
        let homePath = fm.homeDirectoryForCurrentUser.path

        for path in nodeSearchPaths {
            let expanded = path
                .replacingOccurrences(of: "$HOME", with: homePath)
                .replacingOccurrences(of: "~", with: homePath)

            // 处理通配符（如 .nvm/versions/node/*/bin/node）
            if expanded.contains("*") {
                if let matches = glob(pattern: expanded), let first = matches.first {
                    return first
                }
                continue
            }

            if fm.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        // 最后尝试 which node
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "which node 2>/dev/null"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let output, !output.isEmpty, fm.isExecutableFile(atPath: output) {
                    return output
                }
            }
        } catch {
            // 忽略
        }

        return nil
    }

    // MARK: - 辅助方法

    /// 简易 glob 匹配
    private static func glob(pattern: String) -> [String]? {
        // 使用 shell 的 ls 命令做 glob
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "ls -1d \(pattern) 2>/dev/null"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return output
                    .split(separator: "\n")
                    .map(String.init)
                    .filter { FileManager.default.isExecutableFile(atPath: $0) }
            }
        } catch {
            // 忽略
        }

        return nil
    }

    // MARK: - 诊断信息

    /// 生成人类可读的健康状态描述
    static func healthDescription(for health: ServiceHealth) -> String {
        switch health {
        case .notApplicable:
            return "Not a Vue project (no package.json found)"
        case .ready(let config):
            return "Volar ready (Vue \(config.vueVersion == .vue2 ? "2" : "3"), hybrid=\(config.hybridMode))"
        case .nodeNotFound:
            return "Node.js not found. Install Node.js to enable Volar."
        case .volarNotFound:
            return "Volar not installed. Run `npm install -D @vue/language-server` in your project."
        case .vueNotFound:
            return "Vue dependency not found in package.json"
        }
    }
}
