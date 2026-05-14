import Foundation

/// Vite 项目检测与配置桥接
///
/// 检测 Vue 项目是否使用 Vite，解析 Vite 配置中的开发服务器信息，
/// 并提供开发脚本执行建议。
struct ViteBridge: Sendable {
    nonisolated static let emoji = "⚡"

    /// Vite 配置解析结果
    struct ViteConfig: Sendable {
        /// 配置文件路径
        let configPath: String

        /// 开发服务器端口（默认 5173）
        let devPort: Int?

        /// 开发服务器主机（默认 localhost）
        let devHost: String?

        /// 是否为 Vue 插件项目
        let isVueProject: Bool

        /// 项目根目录
        let rootPath: String

        /// 开发服务器 URL
        var devServerURL: String {
            let port = devPort ?? 5173
            let host = devHost ?? "localhost"
            return "http://\(host):\(port)"
        }
    }

    /// Vite 配置文件名
    private static let configFileNames: [String] = [
        "vite.config.ts",
        "vite.config.js",
        "vite.config.mts",
        "vite.config.mjs",
    ]

    /// 常用 Vite 插件名
    private static let vuePluginNames: [String] = [
        "@vitejs/plugin-vue",
        "@vitejs/plugin-vue-jsx",
        "@vitejs/plugin-vue",
        "vite-plugin-vue",
    ]

    // MARK: - 公开方法

    /// 检测指定项目是否使用 Vite + Vue
    ///
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: Vite 配置信息，未检测到则返回 nil
    static func detect(projectPath: String) -> ViteConfig? {
        // 1. 检查 Vite 配置文件是否存在
        guard let configPath = findConfigFile(in: projectPath) else { return nil }

        // 2. 读取配置文件内容，检测是否使用了 Vue 插件
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            // 配置文件存在但无法读取，返回基本信息
            return ViteConfig(
                configPath: configPath,
                devPort: nil,
                devHost: nil,
                isVueProject: false,
                rootPath: projectPath
            )
        }

        let isVueProject = content.contains("@vitejs/plugin-vue")
            || content.contains("vue()")
            || content.contains("createVuePlugin")

        // 3. 尝试解析端口和主机
        let (port, host) = parseServerConfig(from: content)

        return ViteConfig(
            configPath: configPath,
            devPort: port,
            devHost: host,
            isVueProject: isVueProject,
            rootPath: projectPath
        )
    }

    /// 检测 Vite 开发服务器是否正在运行
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - port: 端口号（可选，默认 5173）
    /// - Returns: 是否正在运行
    static func isDevServerRunning(projectPath: String, port: Int = 5173) -> Bool {
        // 尝试连接端口
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
        process.arguments = ["-iTCP:\(port)", "-sTCP:LISTEN", "-t"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return process.terminationStatus == 0 && !(output ?? "").isEmpty
        } catch {
            return false
        }
    }

    /// 生成启动 Vite 开发服务器的命令
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - packageManager: 包管理器（可选，自动检测）
    /// - Returns: 命令字符串
    static func devServerCommand(projectPath: String, packageManager: String? = nil) -> String {
        let manager = packageManager ?? detectPackageManager(projectPath: projectPath)

        switch manager {
        case "npm": return "npm run dev"
        case "pnpm": return "pnpm run dev"
        case "yarn": return "yarn dev"
        case "bun": return "bun run dev"
        default: return "npm run dev"
        }
    }

    /// 生成构建生产版本的命令
    ///
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - packageManager: 包管理器（可选）
    /// - Returns: 命令字符串
    static func buildCommand(projectPath: String, packageManager: String? = nil) -> String {
        let manager = packageManager ?? detectPackageManager(projectPath: projectPath)

        switch manager {
        case "npm": return "npm run build"
        case "pnpm": return "pnpm run build"
        case "yarn": return "yarn build"
        case "bun": return "bun run build"
        default: return "npm run build"
        }
    }

    // MARK: - 私有方法

    /// 在项目中查找 Vite 配置文件
    private static func findConfigFile(in projectPath: String) -> String? {
        for fileName in configFileNames {
            let path = (projectPath as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// 从 Vite 配置内容中解析服务器端口和主机
    private static func parseServerConfig(from content: String) -> (port: Int?, host: String?) {
        var port: Int?
        var host: String?

        // 匹配 server.port = xxxx 或 port: xxxx
        let portPatterns = [
            #"server:\s*\{[^}]*port:\s*(\d+)"#,
            #"port:\s*(\d+)"#,
            #"--port\s+(\d+)"#,
        ]

        for pattern in portPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content),
               let parsedPort = Int(content[range]) {
                port = parsedPort
                break
            }
        }

        // 匹配 server.host = 'xxx' 或 host: 'xxx'
        let hostPatterns = [
            #"server:\s*\{[^}]*host:\s*['"]([^'"]+)['"]"#,
            #"host:\s*['"]([^'"]+)['"]"#,
            #"--host\s+(['"]?)([^'"\s]+)\1"#,
        ]

        for pattern in hostPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                // 尝试捕获组 1 和 2
                for i in 1...2 {
                    if let range = Range(match.range(at: i), in: content) {
                        host = String(content[range])
                        break
                    }
                }
                if host != nil { break }
            }
        }

        return (port, host)
    }

    /// 自动检测包管理器
    private static func detectPackageManager(projectPath: String) -> String {
        let fm = FileManager.default

        // 检查 packageManager 字段（pnpm-lock.yaml, yarn.lock, bun.lockb）
        if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("pnpm-lock.yaml")) {
            return "pnpm"
        }
        if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("yarn.lock")) {
            return "yarn"
        }
        if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("bun.lockb")) {
            return "bun"
        }
        if fm.fileExists(atPath: (projectPath as NSString).appendingPathComponent("bun.lock")) {
            return "bun"
        }

        return "npm"
    }
}
