import Foundation

/// LSP 配置：定义语言服务器二进制路径和默认参数
/// 参考 CodeEdit 的 LanguageServerBinary 结构
struct LumiLSPConfig {
    
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
    
    // MARK: - Default Server Discovery
    
    /// 查找语言服务器路径
    static func findServer(for languageId: String) -> String? {
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
    
    /// 获取默认配置
    static func defaultConfig(for languageId: String) -> ServerConfig? {
        guard let path = findServer(for: languageId) else { return nil }
        return ServerConfig(languageId: languageId, execPath: path)
    }
    
    // MARK: - Private Helpers
    
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
