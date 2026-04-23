import Foundation
import os

/// LSP 配置：定义语言服务器二进制路径和默认参数
struct LSPConfig {

    /// 当前内建支持的语言 ID（用于可用性探测和 UI 状态）
    static let supportedLanguageIds: [String] = [
        "swift",
        "python",
        "typescript",
        "javascript",
        "rust",
        "go",
        "cpp",
        "c",
        "objective-c",
        "objective-cpp",
    ]

    /// 语言服务器二进制配置
    struct ServerConfig {
        let languageId: String
        let execPath: String
        let arguments: [String]
        let env: [String: String]

        init(
            languageId: String,
            execPath: String,
            arguments: [String] = [],
            env: [String: String] = [:]
        ) {
            self.languageId = languageId
            self.execPath = execPath
            self.arguments = arguments
            self.env = env
        }
    }

    // MARK: - Server Path Cache

    /// 路径检测结果缓存（languageId → 路径或 nil）
    /// 避免重复 fork 子进程检测服务器路径
    /// 使用 nonisolated(unsafe) 标注，实际线程安全由 pathCacheLock 保证
    private static let pathCacheLock = NSLock()
    nonisolated(unsafe) private static var _pathCache: [String: String?] = [:]

    /// 缓存是否已经执行过完整扫描
    nonisolated(unsafe) private static var _fullScanCompleted = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.config")

    // MARK: - Default Server Discovery

    /// 查找语言服务器路径（带缓存，线程安全）
    static func findServer(for languageId: String) -> String? {
        pathCacheLock.lock()
        if let cached = _pathCache[languageId] {
            pathCacheLock.unlock()
            return cached
        }
        pathCacheLock.unlock()

        let result = findServerUncached(for: languageId)

        pathCacheLock.lock()
        _pathCache[languageId] = result
        pathCacheLock.unlock()

        return result
    }

    /// 获取默认配置
    static func defaultConfig(for languageId: String) -> ServerConfig? {
        guard let path = findServer(for: languageId) else { return nil }
        return ServerConfig(languageId: languageId, execPath: path)
    }

    // MARK: - Async Availability Check

    /// 在后台线程执行所有语言的可用性检测，结果写入缓存。
    /// 调用方应在非主线程调用此方法（如 Task.detached）。
    @discardableResult
    static func warmUpCacheInBackground() async -> Bool {
        await Task.detached(priority: .utility) {
            var available = false
            for languageId in supportedLanguageIds {
                let path = findServer(for: languageId)
                if path != nil {
                    available = true
                }
            }
            _fullScanCompleted = true
            logger.info("LSP 配置预热完成，缓存 \(_pathCache.count) 条记录")
            return available
        }.value
    }

    /// 重置缓存（用于测试或服务器安装变更后刷新）
    static func resetCache() {
        pathCacheLock.lock()
        _pathCache.removeAll()
        _fullScanCompleted = false
        pathCacheLock.unlock()
    }

    // MARK: - Private Helpers

    /// 实际查找（不查缓存）
    private static func findServerUncached(for languageId: String) -> String? {
        switch languageId {
        case "swift":
            return findSourceKitLSP()
        case "python":
            return findCommand("pylsp") ?? findCommand("pyright-langserver")
        case "typescript":
            return findCommand("typescript-language-server")
        case "javascript":
            return findCommand("typescript-language-server")
        case "rust":
            return findCommand("rust-analyzer")
        case "go":
            return findCommand("gopls")
        case "cpp", "c", "objective-c", "objective-cpp":
            return findCommand("clangd")
        default:
            return nil
        }
    }

    private static func findSourceKitLSP() -> String? {
        let xcodePaths = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
            "/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
        ]
        for path in xcodePaths where FileManager.default.fileExists(atPath: path) {
            return path
        }
        return try? runShellCommand("xcrun", args: ["--find", "sourcekit-lsp"])?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func findCommand(_ command: String) -> String? {
        return try? runShellCommand("/usr/bin/which", args: [command])?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runShellCommand(_ path: String, args: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
