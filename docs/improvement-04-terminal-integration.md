# 改进建议：智能终端集成

**参考产品**: Cursor, Claude Code, Warp  
**优先级**: 🟠 高  
**影响范围**: TerminalPlugin, AgentTool, UI

---

## 背景

Cursor 和 Claude Code 都提供了深度集成的终端体验：

- AI 可以直接在终端执行命令
- 命令输出自动反馈给 AI
- 支持交互式命令
- 智能命令建议和补全

当前 Lumi 的 `TerminalPlugin` 可能缺少这些深度集成功能。

---

## 改进方案

### 1. 终端会话管理

```swift
/// 终端会话管理器
class TerminalSessionManager: ObservableObject {
    /// 活跃的终端会话
    @Published var activeSessions: [UUID: TerminalSession] = [:]
    
    /// 默认 Shell
    private let defaultShell: String
    
    /// 创建新会话
    func createSession(
        workingDirectory: String? = nil,
        environment: [String: String] = [:]
    ) async throws -> TerminalSession {
        let session = TerminalSession(
            id: UUID(),
            shell: defaultShell,
            workingDirectory: workingDirectory ?? FileManager.default.currentDirectoryPath,
            environment: environment
        )
        
        activeSessions[session.id] = session
        
        // 设置输出监听
        session.onOutput { [weak self] output in
            await self?.handleSessionOutput(session.id, output: output)
        }
        
        return session
    }
    
    /// 执行命令
    func executeCommand(
        sessionId: UUID,
        command: String,
        timeout: TimeInterval? = nil
    ) async throws -> CommandResult {
        guard let session = activeSessions[sessionId] else {
            throw TerminalError.sessionNotFound
        }
        
        return try await session.execute(command, timeout: timeout)
    }
    
    /// 处理会话输出
    private func handleSessionOutput(
        _ sessionId: UUID,
        output: TerminalOutput
    ) async {
        // 通知 AI 上下文更新
        NotificationCenter.default.post(
            name: .terminalOutputDidChange,
            object: nil,
            userInfo: [
                "sessionId": sessionId,
                "output": output
            ]
        )
    }
}

/// 终端会话
class TerminalSession {
    let id: UUID
    let shell: String
    let workingDirectory: String
    let environment: [String: String]
    
    private var process: Process?
    private var outputBuffer: AsyncStream<TerminalOutput>
    
    /// 执行命令
    func execute(
        _ command: String,
        timeout: TimeInterval? = nil
    ) async throws -> CommandResult {
        let startTime = Date()
        
        // 创建进程
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.currentDirectoryPath = workingDirectory
        
        // 设置管道
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env
        
        // 执行
        try process.run()
        
        // 读取输出
        var output = ""
        for try await line in pipe.fileHandleForReading.bytes.lines {
            output += line + "\n"
        }
        
        process.waitUntilExit()
        
        return CommandResult(
            command: command,
            exitCode: process.terminationStatus,
            output: output,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 发送输入（用于交互式命令）
    func sendInput(_ input: String) async throws {
        guard let process = process, process.isRunning else {
            throw TerminalError.processNotRunning
        }
        
        guard let stdin = process.standardInput as? Pipe else {
            throw TerminalError.noStdin
        }
        
        try input.write(to: stdin.fileHandleForWriting)
    }
    
    /// 中断当前命令
    func interrupt() {
        process?.interrupt()
    }
    
    /// 终止会话
    func terminate() {
        process?.terminate()
    }
}

/// 命令执行结果
struct CommandResult {
    let command: String
    let exitCode: Int32
    let output: String
    let duration: TimeInterval
    let success: Bool { exitCode == 0 }
}

/// 终端输出
struct TerminalOutput {
    let content: String
    let type: OutputType
    let timestamp: Date
    
    enum OutputType {
        case stdout
        case stderr
        case control  // ANSI 控制序列
    }
}
```

---

### 2. AI-终端桥接

```swift
/// AI 终端桥接
class AITerminalBridge {
    let sessionManager: TerminalSessionManager
    let llmService: LLMService
    
    /// AI 执行命令
    func executeWithAI(
        _ request: String,
        in session: TerminalSession
    ) async throws -> AIExecutionResult {
        // 1. AI 理解请求并生成命令
        let command = try await generateCommand(
            from: request,
            context: session.currentContext
        )
        
        // 2. 执行命令
        let result = try await sessionManager.executeCommand(
            sessionId: session.id,
            command: command
        )
        
        // 3. AI 分析输出
        let analysis = try await analyzeOutput(
            command: command,
            output: result.output,
            exitCode: result.exitCode
        )
        
        // 4. 如果失败，尝试修复
        if !result.success {
            let fixSuggestion = try await suggestFix(
                command: command,
                error: result.output,
                context: session.currentContext
            )
            
            return AIExecutionResult(
                command: command,
                result: result,
                analysis: analysis,
                fixSuggestion: fixSuggestion
            )
        }
        
        return AIExecutionResult(
            command: command,
            result: result,
            analysis: analysis,
            fixSuggestion: nil
        )
    }
    
    /// 从自然语言生成命令
    private func generateCommand(
        from request: String,
        context: TerminalContext
    ) async throws -> String {
        let prompt = """
        你是一个终端命令专家。根据用户的请求生成合适的 shell 命令。
        
        当前目录: \(context.workingDirectory)
        操作系统: \(context.os)
        Shell: \(context.shell)
        
        用户请求: \(request)
        
        请只返回需要执行的命令，不要解释。
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return response.content.trimmingCharacters(in: .newlines)
    }
    
    /// 分析命令输出
    private func analyzeOutput(
        command: String,
        output: String,
        exitCode: Int32
    ) async throws -> String {
        let prompt = """
        分析以下命令执行结果，用简洁的语言解释发生了什么：
        
        命令: \(command)
        退出码: \(exitCode)
        输出:
        \(output)
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return response.content
    }
    
    /// 建议修复方案
    private func suggestFix(
        command: String,
        error: String,
        context: TerminalContext
    ) async throws -> FixSuggestion {
        let prompt = """
        命令执行失败，请分析错误并提供修复建议。
        
        命令: \(command)
        错误输出:
        \(error)
        
        当前目录: \(context.workingDirectory)
        
        请提供：
        1. 错误原因分析
        2. 修复建议（具体的命令或步骤）
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return FixSuggestion(
            analysis: response.content,
            suggestedCommands: extractCommands(from: response.content)
        )
    }
}

/// AI 执行结果
struct AIExecutionResult {
    let command: String
    let result: CommandResult
    let analysis: String
    let fixSuggestion: FixSuggestion?
}

/// 修复建议
struct FixSuggestion {
    let analysis: String
    let suggestedCommands: [String]
}
```

---

### 3. 智能命令补全

```swift
/// 智能命令补全器
class SmartCommandCompleter {
    let history: CommandHistory
    let llmService: LLMService
    
    /// 历史命令
    struct CommandHistory {
        var commands: [(command: String, timestamp: Date, success: Bool)] = []
        
        mutating func add(command: String, success: Bool) {
            commands.append((command, Date(), success))
            // 保留最近 1000 条
            if commands.count > 1000 {
                commands.removeFirst(commands.count - 1000)
            }
        }
        
        func search(prefix: String) -> [String] {
            commands
                .filter { $0.command.hasPrefix(prefix) && $0.success }
                .map { $0.command }
                .uniqued()
                .prefix(10)
        }
    }
    
    /// 获取补全建议
    func getCompletions(
        for partialCommand: String,
        context: TerminalContext
    ) async -> [CommandCompletion] {
        var completions: [CommandCompletion] = []
        
        // 1. 历史补全
        let historyCompletions = history.search(prefix: partialCommand)
        completions.append(contentsOf: historyCompletions.map {
            CommandCompletion(command: $0, source: .history, score: 0.8)
        })
        
        // 2. AI 补全
        let aiCompletions = await getAICompletions(partialCommand: partialCommand, context: context)
        completions.append(contentsOf: aiCompletions)
        
        // 按分数排序
        return completions.sorted { $0.score > $1.score }.prefix(5).map { $0 }
    }
    
    /// AI 补全
    private func getAICompletions(
        partialCommand: String,
        context: TerminalContext
    ) async -> [CommandCompletion] {
        let prompt = """
        基于部分命令，预测完整的命令。返回最多 3 个可能的补全，每行一个。
        
        当前目录: \(context.workingDirectory)
        操作系统: \(context.os)
        部分命令: \(partialCommand)
        
        只返回可能的命令，不要解释。
        """
        
        do {
            let response = try await llmService.sendMessage(
                messages: [ChatMessage(role: .user, content: prompt)],
                config: currentConfig
            )
            
            return response.content
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { CommandCompletion(command: $0, source: .ai, score: 0.9) }
        } catch {
            return []
        }
    }
}

/// 命令补全结果
struct CommandCompletion {
    let command: String
    let source: CompletionSource
    let score: Double
    
    enum CompletionSource {
        case history
        case ai
        case filesystem
        case manpage
    }
}
```

---

### 4. 终端 UI 组件

```swift
/// SwiftUI 终端视图
struct TerminalView: View {
    @StateObject var session: TerminalSession
    @StateObject var completer: SmartCommandCompleter
    @State private var commandInput: String = ""
    @State private var completions: [CommandCompletion] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 输出区域
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.outputHistory) { output in
                            Text(output.content)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(output.type.color)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.outputHistory.count) { _ in
                    proxy.scrollTo(session.outputHistory.last?.id, anchor: .bottom)
                }
            }
            
            Divider()
            
            // 输入区域
            HStack(spacing: 8) {
                Text(session.prompt)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                
                TextField("", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit {
                        executeCommand()
                    }
                    .onChange(of: commandInput) { newValue in
                        Task {
                            completions = await completer.getCompletions(
                                for: newValue,
                                context: session.context
                            )
                        }
                    }
                
                Button("执行") {
                    executeCommand()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 补全建议
            if !completions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(completions, id: \.command) { completion in
                            Button(completion.command) {
                                commandInput = completion.command
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 32)
            }
        }
        .background(Color.black)
        .foregroundColor(.white)
    }
    
    private func executeCommand() {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        commandInput = ""
        
        Task {
            try? await session.execute(command)
        }
    }
}
```

---

### 5. 命令历史分析

```swift
/// 命令历史分析器
class CommandHistoryAnalyzer {
    /// 分析命令使用模式
    func analyzePatterns(in history: [CommandRecord]) -> CommandPatterns {
        // 最常用命令
        let frequentCommands = history
            .map { $0.command.split(separator: " ").first.map(String.init) ?? "" }
            .filter { !$0.isEmpty }
            .frequencies()
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        // 常见错误
        let commonErrors = history
            .filter { !$0.success }
            .map { ($0.command, $0.output) }
            .frequencies()
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        // 时间分布
        let hourlyDistribution = history
            .map { Calendar.current.component(.hour, from: $0.timestamp) }
            .frequencies()
        
        return CommandPatterns(
            frequentCommands: frequentCommands,
            commonErrors: commonErrors,
            hourlyDistribution: hourlyDistribution
        )
    }
    
    /// 生成命令别名建议
    func suggestAliases(for patterns: CommandPatterns) -> [AliasSuggestion] {
        var suggestions: [AliasSuggestion] = []
        
        // 检测长命令的重复使用
        for command in patterns.frequentCommands where command.count > 10 {
            suggestions.append(AliasSuggestion(
                originalCommand: command,
                suggestedAlias: generateAlias(for: command),
                reason: "此命令使用频繁，建议创建别名"
            ))
        }
        
        return suggestions
    }
}
```

---

## 实施计划

### 阶段 1: 基础终端 (2 周)
1. 实现 `TerminalSessionManager`
2. 创建基础终端 UI
3. 集成 Shell 执行

### 阶段 2: AI 集成 (2 周)
1. 实现 `AITerminalBridge`
2. 添加自然语言命令生成
3. 实现输出分析

### 阶段 3: 智能功能 (1 周)
1. 实现智能补全
2. 添加历史分析
3. 优化 UI 体验

---

## 预期效果

1. **效率提升**: 通过 AI 辅助，命令输入效率提升 50%
2. **错误减少**: 智能分析和修复，减少 40% 的命令错误
3. **学习曲线**: 新用户更容易上手终端操作
4. **历史可追溯**: 所有命令和输出都有记录

---

## 参考资源

- [Warp Terminal](https://www.warp.dev/)
- [iTerm2 Python API](https://iterm2.com/python-api/)
- [Swift Process](https://developer.apple.com/documentation/foundation/process)

---

*创建时间: 2026-03-13*