import Foundation
import MagicKit

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        let copy = data
        lock.unlock()
        return copy
    }
}

/// 项目命令加载服务 - 负责从 .agent/commands 目录加载命令
actor ProjectCommandLoader: SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false
    
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // MARK: - 公开 API
    
    /// 从指定项目路径加载所有命令
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 项目命令列表
    func loadCommands(for projectPath: String) async -> [ProjectCommand] {
        let commandsDir = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")
        
        guard fileManager.fileExists(atPath: commandsDir.path) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 项目命令目录不存在：\(commandsDir.path)")
            }
            return []
        }
        
        return await loadCommands(from: commandsDir, source: .project(projectPath))
    }
    
    /// 从用户全局目录加载命令 ~/.agent/commands
    func loadUserCommands() async -> [ProjectCommand] {
        guard let homeDir = FileManager.default.homeDirectoryForCurrentUser as URL? else {
            return []
        }
        
        let commandsDir = homeDir
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")
        
        guard fileManager.fileExists(atPath: commandsDir.path) else {
            return []
        }
        
        return await loadCommands(from: commandsDir, source: .user)
    }
    
    /// 从插件目录加载命令
    /// - Parameters:
    ///   - pluginName: 插件名称
    ///   - pluginPath: 插件路径
    func loadPluginCommands(pluginName: String, pluginPath: String) async -> [ProjectCommand] {
        let commandsDir = URL(fileURLWithPath: pluginPath)
            .appendingPathComponent("commands")
        
        guard fileManager.fileExists(atPath: commandsDir.path) else {
            return []
        }
        
        return await loadCommands(from: commandsDir, source: .plugin(pluginName))
    }
    
    // MARK: - 私有方法
    
    /// 从目录加载命令
    private func loadCommands(from directory: URL, source: ProjectCommand.Source) async -> [ProjectCommand] {
        var commands: [ProjectCommand] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        // 收集所有文件 URL
        let fileURLs = enumerator.compactMap { $0 as? URL }
        
        for fileURL in fileURLs {
            // 只处理 .md 文件
            guard fileURL.pathExtension == "md" else { continue }
            
            // 获取相对路径作为命令名
            let relativePath = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let commandName = relativePath.replacingOccurrences(of: ".md", with: "")
            
            // 跳过目录分隔符，使用最后一级作为命令名
            let finalCommandName = commandName.split(separator: "/").last.map(String.init) ?? commandName
            
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)❌ 无法读取命令文件：\(fileURL.path)")
                }
                continue
            }
            
            // 解析 frontmatter
            let (frontmatter, body) = CommandFrontmatter.parse(from: content)
            
            // 提取描述
            let description: String
            if let frontmatterDesc = frontmatter?.description {
                description = frontmatterDesc
            } else {
                // 使用文件第一行作为描述
                let firstLine = body.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "No description"
                // 移除 Markdown 标题标记
                description = firstLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            }
            
            let command = ProjectCommand(
                name: finalCommandName,
                filePath: fileURL.path,
                description: description,
                content: body,
                allowedTools: frontmatter?.allowedTools,
                model: frontmatter?.model,
                argumentHint: frontmatter?.argumentHint,
                disableModelInvocation: frontmatter?.disableModelInvocation ?? false,
                source: source
            )
            
            commands.append(command)
            
            if Self.verbose {
                AppLogger.core.info("\(Self.t)✅ 加载命令：\(command.slashCommand) [\(self.sourceDescription(source))]")
            }
        }
        
        // 按名称排序
        commands.sort { $0.name < $1.name }
        
        return commands
    }
    
    private func sourceDescription(_ source: ProjectCommand.Source) -> String {
        switch source {
        case .project(let path):
            return "project: \(path)"
        case .user:
            return "user"
        case .plugin(let name):
            return "plugin: \(name)"
        }
    }
}

// MARK: - 命令执行服务

/// 命令执行服务 - 负责处理和执行项目命令
actor ProjectCommandExecutor: SuperLog {
    nonisolated static let emoji = "⚡"
    nonisolated static let verbose = false
    
    private let commandLoader: ProjectCommandLoader
    private var loadedCommands: [ProjectCommand] = []
    private var currentProjectPath: String?
    
    init(commandLoader: ProjectCommandLoader = ProjectCommandLoader()) {
        self.commandLoader = commandLoader
    }
    
    // MARK: - 公开 API
    
    /// 重新加载项目命令
    func reloadCommands(for projectPath: String) async {
        currentProjectPath = projectPath
        
        var allCommands: [ProjectCommand] = []
        
        // 加载用户全局命令
        let userCommands = await commandLoader.loadUserCommands()
        allCommands.append(contentsOf: userCommands)
        
        // 加载项目命令
        let projectCommands = await commandLoader.loadCommands(for: projectPath)
        allCommands.append(contentsOf: projectCommands)
        
        // TODO: 加载插件命令（当插件系统就绪时）
        
        loadedCommands = allCommands
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📚 已加载 \(self.loadedCommands.count) 个命令")
        }
    }
    
    /// 检查输入是否为已知的斜杠命令
    func isSlashCommand(_ input: String) -> Bool {
        guard input.hasPrefix("/") else { return false }
        
        let command = extractCommandName(from: input)
        return self.loadedCommands.contains { $0.name == command }
    }
    
    /// 获取所有可用的命令
    func getAllCommands() -> [ProjectCommand] {
        return loadedCommands
    }
    
    /// 执行斜杠命令
    /// - Parameters:
    ///   - input: 用户输入（如 "/commit Hello"）
    /// - Returns: 执行结果，包含处理后的内容
    func executeSlashCommand(_ input: String) async -> SlashCommandResult {
        guard input.hasPrefix("/") else { return .notHandled }

        let commandName = extractCommandName(from: input)
        let arguments = extractArguments(from: input)

        // 查找命令
        guard let command = loadedCommands.first(where: { $0.name == commandName }) else {
            return .notHandled
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🚀 执行命令：/\(commandName), 参数：\(arguments)")
        }

        // 处理命令内容
        let processedContent = await processCommandContent(command.content, arguments: arguments, projectPath: currentProjectPath)

        // 返回用户消息，由调用方决定如何处理
        return .userMessage(processedContent, triggerProcessing: true)
    }
    
    // MARK: - 私有方法
    
    private func extractCommandName(from input: String) -> String {
        let components = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        return components.first ?? ""
    }
    
    private func extractArguments(from input: String) -> String {
        let components = input.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
        return components.count > 1 ? components[1] : ""
    }
    
    private func categoryForSource(_ source: ProjectCommand.Source) -> String {
        switch source {
        case .project:
            return "Project"
        case .user:
            return "User"
        case .plugin:
            return "Plugin"
        }
    }
    
    /// 处理命令内容
    /// - Parameters:
    ///   - content: 命令原始内容
    ///   - arguments: 命令行参数
    ///   - projectPath: 项目路径
    /// - Returns: 处理后的内容
    private func processCommandContent(_ content: String, arguments: String, projectPath: String?) async -> String {
        var processed = content
        
        // 1. 替换 $ARGUMENTS
        processed = processed.replacingOccurrences(of: "$ARGUMENTS", with: arguments)
        
        // 2. 替换位置参数 $1, $2, $3...
        let argArray = arguments.split(separator: " ").map(String.init)
        for (index, arg) in argArray.enumerated() {
            let placeholder = "$\(index + 1)"
            processed = processed.replacingOccurrences(of: placeholder, with: arg)
        }
        
        // 3. 处理 Bash 执行 !`command`
        if let cwd = projectPath {
            processed = await executeBashCommands(in: processed, workingDirectory: cwd)
        }
        
        // 4. 处理文件引用 @file-path
        if let cwd = projectPath {
            processed = await processFileReferences(in: processed, projectPath: cwd)
        }
        
        return processed
    }
    
    /// 执行 Bash 命令
    private func executeBashCommands(in content: String, workingDirectory: String) async -> String {
        var result = content
        
        // 查找所有 !`command` 模式
        let pattern = #"!\`([^\`]+)\`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, options: [], range: range)
        
        // 从后向前替换，避免索引偏移问题
        for match in matches.reversed() {
            guard let commandRange = Range(match.range(at: 1), in: result) else { continue }
            let command = String(result[commandRange])
            
            // 执行命令
            let output = await executeCommand(command, workingDirectory: workingDirectory)
            
            // 替换 !`command` 为输出
            if let fullMatchRange = Range(match.range, in: result) {
                result.replaceSubrange(fullMatchRange, with: output)
            }
        }
        
        return result
    }
    
    /// 执行单个命令
    private func executeCommand(_ command: String, workingDirectory: String) async -> String {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/bash")
                task.arguments = ["-c", command]
                task.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe

                let buffer = LockedDataBuffer()
                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { h in
                    let chunk = h.availableData
                    if !chunk.isEmpty { buffer.append(chunk) }
                }

                do {
                    try task.run()
                } catch {
                    handle.readabilityHandler = nil
                    continuation.resume(returning: "Error: \(error.localizedDescription)")
                    return
                }

                await withCheckedContinuation { termCont in
                    task.terminationHandler = { _ in
                        termCont.resume()
                    }
                }

                handle.readabilityHandler = nil
                let final = handle.availableData
                if !final.isEmpty { buffer.append(final) }

                let output = String(data: buffer.snapshot(), encoding: .utf8) ?? ""
                continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
    
    /// 处理文件引用 @file-path
    private func processFileReferences(in content: String, projectPath: String) async -> String {
        var result = content
        
        // 查找所有 @file-path 模式
        let pattern = #"@([^\s\`]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, options: [], range: range)
        
        // 从后向前替换
        for match in matches.reversed() {
            guard let pathRange = Range(match.range(at: 1), in: result) else { continue }
            let filePath = String(result[pathRange])
            
            // 解析文件路径
            let fileURL: URL
            if filePath.hasPrefix("/") {
                fileURL = URL(fileURLWithPath: filePath)
            } else if filePath.hasPrefix("~") {
                fileURL = URL(fileURLWithPath: NSString(string: filePath).expandingTildeInPath)
            } else {
                fileURL = URL(fileURLWithPath: projectPath).appendingPathComponent(filePath)
            }
            
            // 读取文件内容
            if let fileContent = try? String(contentsOf: fileURL, encoding: .utf8) {
                let replacement = "```\n// File: \(filePath)\n\(fileContent)\n```"
                if let fullMatchRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullMatchRange, with: replacement)
                }
            } else {
                // 文件不存在，保留原始引用或添加错误提示
                if let fullMatchRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullMatchRange, with: "@\(filePath) [文件不存在]")
                }
            }
        }
        
        return result
    }
}
