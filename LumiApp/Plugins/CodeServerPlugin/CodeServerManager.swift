import Foundation
import os

/// Code Server 管理器
///
/// 负责 code-server 进程的启动、停止、配置写入和状态监控。
/// 使用单例模式，确保全局只有一个 code-server 实例。
@MainActor
final class CodeServerManager: ObservableObject {
    static let shared = CodeServerManager()

    // MARK: - Published State

    /// code-server 是否正在运行
    @Published var isRunning: Bool = false

    /// 当前端口
    @Published var port: Int = 8080

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private

    private var process: Process?
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "code-server")

    /// 默认写入 settings.json 的配置项
    private static let defaultSettings: [String: Any] = CodeServerDefaultSettings.values

    private init() {}

    // MARK: - Public

    /// 启动 code-server
    /// - Parameter port: 监听端口，默认 8080
    func start(port: Int = 8080) {
        guard !isRunning else {
            logger.info("code-server 已在运行中")
            return
        }

        self.port = port

        guard let codeServerPath = findCodeServer() else {
            errorMessage = "未找到 code-server，请先安装：brew install code-server"
            logger.error("code-server 未安装")
            return
        }

        // 1. 写入默认配置
        ensureDefaultSettings()

        // 2. 启动进程
        let task = Process()
        task.executableURL = URL(fileURLWithPath: codeServerPath)
        task.arguments = [
            "--auth", "none",
            "--port", "\(port)",
            "--bind-addr", "127.0.0.1:\(port)",
            "--disable-telemetry",
            "--disable-update-check"
        ]
        task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        // 捕获输出
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        let outHandle = outPipe.fileHandleForReading
        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                self?.logger.debug("code-server: \(line.trimmingCharacters(in: .newlines))")
            }
        }

        let errHandle = errPipe.fileHandleForReading
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                self?.logger.error("code-server error: \(line.trimmingCharacters(in: .newlines))")
            }
        }

        task.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.process = nil
            }
        }

        do {
            try task.run()
            process = task
            isRunning = true
            errorMessage = nil
            logger.info("code-server 已启动，端口: \(port)")
        } catch {
            errorMessage = "启动 code-server 失败: \(error.localizedDescription)"
            logger.error("启动失败: \(error.localizedDescription)")
        }
    }

    /// 停止 code-server
    func stop() {
        guard isRunning else { return }

        process?.terminate()
        process?.waitUntilExit()
        process = nil
        isRunning = false
        logger.info("code-server 已停止")
    }

    /// 检查 code-server 是否可访问
    /// - Returns: 是否可访问
    func isServerReachable() async -> Bool {
        let url = URL(string: "http://127.0.0.1:\(port)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Settings

    /// 确保默认配置已写入 settings.json
    private func ensureDefaultSettings() {
        let settingsURL = settingsFileURL()

        // 如果 settings.json 已存在，合并默认值（不覆盖已有配置）
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            mergeDefaultSettings(into: settingsURL)
        } else {
            writeDefaultSettings(to: settingsURL)
        }
    }

    /// 写入默认 settings.json
    private func writeDefaultSettings(to url: URL) {
        do {
            let parentDir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let data = try JSONSerialization.data(withJSONObject: Self.defaultSettings, options: .prettyPrinted)
            try data.write(to: url)
            logger.info("✅ 已创建 code-server 默认配置: \(url.path)")
        } catch {
            logger.warning("⚠️ 写入 code-server 配置失败: \(error.localizedDescription)")
        }
    }

    /// 将默认配置合并到已有 settings.json（不覆盖已有值）
    private func mergeDefaultSettings(into url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            // 仅写入不存在的键
            for (key, value) in Self.defaultSettings {
                if existing[key] == nil {
                    existing[key] = value
                }
            }

            let newData = try JSONSerialization.data(withJSONObject: existing, options: .prettyPrinted)
            try newData.write(to: url)
            logger.info("✅ 已合并 code-server 默认配置: \(url.path)")
        } catch {
            logger.warning("⚠️ 合并 code-server 配置失败: \(error.localizedDescription)")
        }
    }

    /// 获取 code-server settings.json 路径
    ///
    /// 路径: ~/.local/share/code-server/User/settings.json
    private func settingsFileURL() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local")
            .appendingPathComponent("share")
            .appendingPathComponent("code-server")
            .appendingPathComponent("User")
            .appendingPathComponent("settings.json")
    }

    // MARK: - Private Helpers

    /// 查找 code-server 可执行文件路径
    private func findCodeServer() -> String? {
        // 1. 检查 PATH 中是否有 code-server
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "which code-server"]
        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // 忽略
        }

        // 2. 常见 Homebrew / Nix 路径
        let commonPaths = [
            "/opt/homebrew/bin/code-server",
            "/usr/local/bin/code-server",
            "/opt/homebrew/opt/code-server/bin/code-server",
            "\(NSHomeDirectory())/.nix-profile/bin/code-server"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}
