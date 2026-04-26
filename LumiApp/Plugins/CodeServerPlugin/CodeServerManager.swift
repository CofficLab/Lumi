import Foundation
import os

/// Code Server 扩展信息
struct CodeServerExtension: Identifiable, Equatable, Hashable {
    let id: String          // 扩展 ID，如 "ms-python.python"
    let name: String        // 扩展名称（从 ID 推导）
    var version: String?    // 版本号（可选）

    var displayName: String {
        // 将 ID 转换为可读名称，如 "ms-python.python" -> "Python"
        name.capitalized
    }
}

/// Open VSX 市场扩展信息
struct OpenVSXExtension: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let description: String?
    let version: String
    let iconUrl: String?
    let downloadCount: Int?
    let averageRating: Double?
    let publisher: String?

    var formattedDownloads: String {
        guard let count = downloadCount else { return "" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    var ratingStars: String {
        guard let rating = averageRating else { return "" }
        let fullStars = Int(rating / 2)
        return String(repeating: "★", count: fullStars) + String(repeating: "☆", count: 5 - fullStars)
    }
}

/// Open VSX 扩展分类
enum ExtensionCategory: String, CaseIterable {
    case all = "全部"
    case programmingLanguages = "编程语言"
    case snippets = "代码片段"
    case linters = "代码检查"
    case themes = "主题"
    case debuggers = "调试器"
    case formatters = "格式化工具"
    case machineLearning = "机器学习"
    case notebooks = "笔记本"
    case testing = "测试"
    case other = "其他"

    var displayName: String { rawValue }

    /// API 查询参数值
    var apiQuery: String? {
        switch self {
        case .all: return nil
        case .programmingLanguages: return "Programming Languages"
        case .snippets: return "Snippets"
        case .linters: return "Linters"
        case .themes: return "Themes"
        case .debuggers: return "Debuggers"
        case .formatters: return "Formatters"
        case .machineLearning: return "Machine Learning"
        case .notebooks: return "Notebooks"
        case .testing: return "Testing"
        case .other: return "Other"
        }
    }
}

/// Code Server 管理器
///
/// 负责 code-server 进程的启动、停止、配置写入和状态监控。
/// 使用单例模式，确保全局只有一个 code-server 实例。
///
/// ## 数据存储
/// 所有数据（扩展、配置、缓存）存储在插件专属目录：
/// `AppConfig.getPluginDBFolderURL(pluginName: "CodeServerPlugin")/code-server/`
/// 避免污染用户目录。
///
/// 目录结构：
/// ```
/// AppConfig.getPluginDBFolderURL(pluginName: "CodeServerPlugin")/
/// └── code-server/
///     ├── User/
///     │   └── settings.json    # 用户配置
///     └── extensions/          # 已安装的扩展
/// ```
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

    /// 通知 WebView 需要重新加载
    @Published var shouldReloadWebView: Bool = false

    /// 已安装的扩展列表
    @Published var installedExtensions: [CodeServerExtension] = []

    /// 是否正在加载扩展列表
    @Published var isLoadingExtensions: Bool = false

    /// 扩展操作错误信息
    @Published var extensionError: String?

    // MARK: - Open VSX Market

    /// Open VSX 搜索关键词
    @Published var searchQuery: String = ""
    /// 搜索结果列表
    @Published var searchResults: [OpenVSXExtension] = []
    /// 是否正在搜索
    @Published var isSearching: Bool = false
    /// 搜索错误信息
    @Published var searchError: String?
    /// 选中的分类
    @Published var selectedCategory: ExtensionCategory = .all

    // MARK: - Data Directory

    /// code-server 数据根目录
    ///
    /// 路径：`AppConfig.getPluginDBFolderURL(pluginName: "CodeServerPlugin")/code-server/`
    private lazy var dataDirectory: URL = {
        let pluginDir = AppConfig.getPluginDBFolderURL(pluginName: "CodeServerPlugin")
        let csDir = pluginDir.appendingPathComponent("code-server", isDirectory: true)
        try? FileManager.default.createDirectory(at: csDir, withIntermediateDirectories: true)
        return csDir
    }()

    /// code-server 用户数据目录（--user-data-dir）
    private var userDataURL: URL { dataDirectory }

    /// code-server 扩展目录（--extensions-dir）
    private var extensionsDirURL: URL { dataDirectory.appendingPathComponent("extensions", isDirectory: true) }

    // MARK: - Private

    private var process: Process?
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "code-server")

    /// 默认写入 settings.json 的配置项
    private static let defaultSettings: [String: Any] = CodeServerDefaultSettings.values

    private init() {}

    // MARK: - Public

    /// 启动 code-server
    /// - Parameters:
    ///   - port: 监听端口，默认 8080
    ///   - openPath: 启动后自动打开的项目路径（可选）
    func start(port: Int = 8080, openPath: String? = nil) {
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

        // 确保扩展目录存在
        try? FileManager.default.createDirectory(at: extensionsDirURL, withIntermediateDirectories: true)

        // 2. 构建启动参数
        var arguments: [String] = [
            "--auth", "none",
            "--port", "\(port)",
            "--bind-addr", "127.0.0.1:\(port)",
            "--disable-telemetry",
            "--disable-update-check",
            "--user-data-dir", userDataURL.path,
            "--extensions-dir", extensionsDirURL.path,
        ]

        // 添加要打开的项目路径
        if let openPath, FileManager.default.fileExists(atPath: openPath) {
            arguments.append(openPath)
            logger.info("📂 启动时自动打开项目: \(openPath)")
        }

        // 3. 启动进程
        let task = Process()
        task.executableURL = URL(fileURLWithPath: codeServerPath)
        task.arguments = arguments
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
            logger.info("code-server 已启动，端口: \(port)，数据目录: \(self.dataDirectory.path)")
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
    /// 路径: `{pluginDataDir}/code-server/User/settings.json`
    private func settingsFileURL() -> URL {
        userDataURL
            .appendingPathComponent("User")
            .appendingPathComponent("settings.json")
    }

    /// 构建 code-server CLI 命令的通用参数
    ///
    /// 包含 `--user-data-dir` 和 `--extensions-dir`，
    /// 确保 CLI 操作（安装/卸载扩展、列出扩展）使用正确的数据目录。
    private func cliDataArgs() -> [String] {
        [
            "--user-data-dir", userDataURL.path,
            "--extensions-dir", extensionsDirURL.path,
        ]
    }

    // MARK: - Extension Management (CLI-based)

    /// 获取已安装的扩展列表
    /// 使用 `code-server --list-extensions` CLI 命令
    func loadInstalledExtensions() {
        guard let codeServerPath = findCodeServer() else {
            extensionError = "未找到 code-server"
            return
        }

        isLoadingExtensions = true
        extensionError = nil

        let cliArgs = cliDataArgs()

        Task.detached { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: codeServerPath)
            task.arguments = ["--list-extensions", "--show-versions"] + cliArgs
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                let extensions = output
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { id in
                        // 有些输出格式是 "publisher.name@version"，只取 ID 部分
                        let parts = id.split(separator: "@")
                        let extId = String(parts[0])
                        let version = parts.count > 1 ? String(parts[1]) : nil
                        return CodeServerExtension(id: extId, name: extId, version: version)
                    }

                await MainActor.run { [weak self] in
                    self?.installedExtensions = extensions
                    self?.isLoadingExtensions = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.extensionError = "获取扩展列表失败: \(error.localizedDescription)"
                    self?.isLoadingExtensions = false
                }
            }
        }
    }

    /// 重载 code-server（使新安装的扩展立即生效）
    ///
    /// 通过更新 `shouldReloadWebView` 标志通知 WKWebView 重新加载页面。
    private func reloadServer() {
        guard isRunning else { return }
        
        // 设置重载标志，触发 WKWebView 重新加载
        shouldReloadWebView = true
        logger.info("🔄 已触发 code-server 重载，扩展将立即生效")
        
        // 延迟重置标志，以便下次安装时能再次触发
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.shouldReloadWebView = false
        }
    }

    /// 安装扩展
    /// 使用 `code-server --install-extension <id>` CLI 命令
    /// - Parameter extensionId: 扩展 ID，如 "ms-python.python"
    /// - Returns: 是否成功
    @discardableResult
    func installExtension(_ extensionId: String) async -> Bool {
        guard let codeServerPath = findCodeServer() else {
            extensionError = "未找到 code-server"
            return false
        }

        extensionError = nil

        let cliArgs = cliDataArgs()

        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: codeServerPath)
            task.arguments = ["--install-extension", extensionId] + cliArgs
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            task.terminationHandler = { [weak self] _ in
                // 读取输出
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let outText = String(data: outData, encoding: .utf8) ?? ""
                let errText = String(data: errData, encoding: .utf8) ?? ""

                // 检查是否成功
                let success = outText.contains("Extension") || !errText.contains("Failed")

                Task { @MainActor [weak self] in
                    if !success {
                        self?.extensionError = "安装扩展失败: \(errText)"
                        self?.logger.error("安装扩展失败: \(errText)")
                    } else {
                        self?.logger.info("✅ 已安装扩展: \(extensionId)")
                        // 如果是图标主题扩展，自动启用
                        self?.applyThemeIfApplicable(extensionId)
                        // 触发 code-server 重载，使扩展立即生效
                        self?.reloadServer()
                        // 刷新列表
                        self?.loadInstalledExtensions()
                    }
                }
                continuation.resume(returning: success)
            }

            do {
                try task.run()
            } catch {
                Task { @MainActor [weak self] in
                    self?.extensionError = "安装扩展失败: \(error.localizedDescription)"
                }
                continuation.resume(returning: false)
            }
        }
    }

    /// 如果安装的是图标主题，自动更新 settings.json 启用该主题
    ///
    /// 通过解析扩展 ID 名称，判断是否可能是图标主题，
    /// 如果是则将其写入 `workbench.iconTheme` 配置。
    private func applyThemeIfApplicable(_ extensionId: String) {
        // 从扩展 ID 中提取名称部分（如 "pkief.material-icon-theme" -> "material-icon-theme"）
        let parts = extensionId.split(separator: ".")
        guard parts.count >= 2 else { return }
        let themeName = String(parts.dropFirst().joined(separator: "."))

        // 判断是否为图标主题（名称包含 icon-theme 或 icons）
        let lowercasedName = themeName.lowercased()
        let isIconTheme = lowercasedName.contains("icon-theme") || lowercasedName.contains("icons")

        guard isIconTheme else { return }

        // 更新 settings.json
        updateSetting(key: "workbench.iconTheme", value: themeName)
        logger.info("🎨 已自动启用图标主题: \(themeName)")
    }

    /// 更新 settings.json 中的单个配置项
    ///
    /// 读取现有配置，更新指定键值后写回文件。
    /// - Parameters:
    ///   - key: 配置键名
    ///   - value: 配置值
    private func updateSetting(key: String, value: Any) {
        let settingsURL = settingsFileURL()

        do {
            var settings: [String: Any] = [:]

            // 读取现有配置
            if FileManager.default.fileExists(atPath: settingsURL.path) {
                let data = try Data(contentsOf: settingsURL)
                settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            }

            // 更新指定键值
            settings[key] = value

            // 写回文件
            let newData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try newData.write(to: settingsURL)
        } catch {
            logger.warning("⚠️ 更新 code-server 配置失败 [\(key)]: \(error.localizedDescription)")
        }
    }

    /// 卸载扩展
    /// 使用 `code-server --uninstall-extension <id>` CLI 命令
    /// - Parameter extensionId: 扩展 ID
    /// - Returns: 是否成功
    @discardableResult
    func uninstallExtension(_ extensionId: String) async -> Bool {
        guard let codeServerPath = findCodeServer() else {
            extensionError = "未找到 code-server"
            return false
        }

        extensionError = nil

        let cliArgs = cliDataArgs()

        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: codeServerPath)
            task.arguments = ["--uninstall-extension", extensionId] + cliArgs
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe

            task.terminationHandler = { [weak self] _ in
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8) ?? ""
                let success = !errText.contains("Failed")

                Task { @MainActor [weak self] in
                    if !success {
                        self?.extensionError = "卸载扩展失败: \(errText)"
                        self?.logger.error("卸载扩展失败: \(errText)")
                    } else {
                        self?.logger.info("✅ 已卸载扩展: \(extensionId)")
                        self?.loadInstalledExtensions()
                    }
                }
                continuation.resume(returning: success)
            }

            do {
                try task.run()
            } catch {
                Task { @MainActor [weak self] in
                    self?.extensionError = "卸载扩展失败: \(error.localizedDescription)"
                }
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Data Management

    /// 在新窗口中打开指定路径
    ///
    /// 使用 `code-server --new-window <path>` 在已运行的 code-server 中打开新项目。
    /// - Parameter path: 项目路径
    func openInNewWindow(path: String) {
        guard let codeServerPath = findCodeServer() else {
            logger.error("未找到 code-server")
            return
        }

        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("项目路径不存在: \(path)")
            return
        }

        // 启动新进程打开项目，使用 --reuse-window 会在当前窗口打开，--new-window 会打开新窗口
        let task = Process()
        task.executableURL = URL(fileURLWithPath: codeServerPath)
        task.arguments = [
            "--new-window",
            path,
            "--user-data-dir", userDataURL.path,
            "--extensions-dir", extensionsDirURL.path,
            "--auth", "none",
        ]
        task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        do {
            try task.run()
            logger.info("📂 已在新窗口打开项目: \(path)")
        } catch {
            logger.error("打开项目失败: \(error.localizedDescription)")
        }
    }

    /// 清除所有 code-server 数据（扩展、配置、缓存）
    ///
    /// ⚠️ 此操作不可逆，会删除所有已安装的扩展和配置。
    func clearAllData() {
        stop()
        try? FileManager.default.removeItem(at: dataDirectory)
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        logger.info("🗑️ 已清除所有 code-server 数据")
    }

    /// 获取数据目录占用的磁盘空间（字节）
    func dataSize() -> Int64 {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: dataDirectory.path) else { return 0 }

        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: dataDirectory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }

    /// 获取格式化的数据目录大小
    var dataSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: dataSize(), countStyle: .file)
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

    /// 检查扩展是否已安装
    func isExtensionInstalled(_ extensionId: String) -> Bool {
        installedExtensions.contains { $0.id == extensionId }
    }

    // MARK: - Open VSX Market Search

    /// 热门扩展列表
    @Published var popularExtensions: [OpenVSXExtension] = []
    /// 是否正在加载热门扩展
    @Published var isLoadingPopular: Bool = false
    /// 热门扩展加载错误
    @Published var popularError: String?

    /// 搜索 Open VSX 扩展市场
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - category: 分类过滤
    ///   - size: 返回结果数量（默认 20）
    ///   - sortBy: 排序方式（默认按相关性）
    func searchMarket(query: String, category: ExtensionCategory = .all, size: Int = 20, sortBy: String = "relevance") {
        fetchMarketResults(query: query, category: category, size: size, sortBy: sortBy, isSearch: true)
    }

    /// 加载热门扩展（按下载量排序）
    /// - Parameters:
    ///   - size: 返回结果数量（默认 30）
    ///   - category: 分类过滤
    func loadPopularExtensions(size: Int = 30, category: ExtensionCategory = .all) {
        guard popularExtensions.isEmpty else { return }
        isLoadingPopular = true
        popularError = nil
        fetchMarketResults(query: "", category: category, size: size, sortBy: "downloadCount", isSearch: false)
    }

    /// 通用市场数据请求
    /// - Parameters:
    ///   - query: 搜索关键词（空表示热门列表）
    ///   - category: 分类过滤
    ///   - size: 返回数量
    ///   - sortBy: 排序方式
    ///   - isSearch: true=搜索结果，false=热门列表
    private func fetchMarketResults(query: String, category: ExtensionCategory, size: Int, sortBy: String, isSearch: Bool) {
        if isSearch {
            isSearching = true
            searchError = nil
        }

        Task.detached { [weak self] in
            guard let self = self else { return }

            // 构建 API URL
            var components = URLComponents(string: "https://open-vsx.org/api/-/search")!
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "size", value: "\(size)")
            ]

            // 搜索关键词
            if !query.isEmpty {
                queryItems.append(URLQueryItem(name: "query", value: query))
            }

            // 排序
            queryItems.append(URLQueryItem(name: "sortBy", value: sortBy))

            // 添加分类过滤
            if let categoryQuery = category.apiQuery {
                queryItems.append(URLQueryItem(name: "category", value: categoryQuery))
            }

            components.queryItems = queryItems

            guard let url = components.url else {
                await MainActor.run { [weak self] in
                    if isSearch {
                        self?.searchError = "构建搜索 URL 失败"
                        self?.isSearching = false
                    } else {
                        self?.popularError = "构建热门扩展 URL 失败"
                        self?.isLoadingPopular = false
                    }
                }
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    await MainActor.run { [weak self] in
                        if isSearch {
                            self?.searchError = "搜索请求失败"
                            self?.isSearching = false
                        } else {
                            self?.popularError = "加载热门扩展失败"
                            self?.isLoadingPopular = false
                        }
                    }
                    return
                }

                // 解析 JSON 响应
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let extensions = json["extensions"] as? [[String: Any]] {

                    let results: [OpenVSXExtension] = extensions.compactMap { ext in
                        guard let namespace = ext["namespace"] as? String,
                              let name = ext["name"] as? String else { return nil }

                        let id = "\(namespace).\(name)"
                        let version = ext["version"] as? String ?? "unknown"
                        let downloadCount = ext["downloadCount"] as? Int
                        let averageRating = ext["averageRating"] as? Double

                        var iconUrl: String? = nil
                        if let files = ext["files"] as? [String: String] {
                            iconUrl = files["icon"]
                        }

                        return OpenVSXExtension(
                            id: id,
                            name: name,
                            displayName: ext["displayName"] as? String ?? name,
                            description: ext["description"] as? String,
                            version: version,
                            iconUrl: iconUrl,
                            downloadCount: downloadCount,
                            averageRating: averageRating,
                            publisher: namespace
                        )
                    }

                    await MainActor.run { [weak self] in
                        if isSearch {
                            self?.searchResults = results
                            self?.isSearching = false
                        } else {
                            self?.popularExtensions = results
                            self?.isLoadingPopular = false
                        }
                    }
                } else {
                    await MainActor.run { [weak self] in
                        if isSearch {
                            self?.searchResults = []
                            self?.isSearching = false
                        } else {
                            self?.popularExtensions = []
                            self?.isLoadingPopular = false
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    if isSearch {
                        self?.searchError = "搜索失败: \(error.localizedDescription)"
                        self?.isSearching = false
                    } else {
                        self?.popularError = "加载失败: \(error.localizedDescription)"
                        self?.isLoadingPopular = false
                    }
                }
            }
        }
    }

    /// 应用已安装的图标主题
    ///
    /// 将指定扩展设置为当前的图标主题，并触发 WebView 重载使其立即生效。
    /// - Parameter extensionId: 扩展 ID，如 "pkief.material-icon-theme"
    func applyIconTheme(_ extensionId: String) {
        let parts = extensionId.split(separator: ".")
        guard parts.count >= 2 else { return }
        let themeName = String(parts.dropFirst().joined(separator: "."))

        // 更新 settings.json
        updateSetting(key: "workbench.iconTheme", value: themeName)
        logger.info("🎨 已应用图标主题: \(themeName)")

        // 触发 WebView 重载使主题立即生效
        reloadServer()
    }

    /// 获取所有已安装的图标主题扩展
    var installedIconThemes: [CodeServerExtension] {
        installedExtensions.filter { ext in
            let lowercasedId = ext.id.lowercased()
            return lowercasedId.contains("icon-theme") || lowercasedId.contains("icons")
        }
    }
}
