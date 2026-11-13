import Foundation

/// 用户终端可见的 `PATH`。
///
/// GUI 启动的 App 只继承系统最小 `PATH`（`/usr/bin:/bin:/usr/sbin:/sbin`），
/// 直接用它判断「命令装完能不能直接用」会得到错误结论：Homebrew、
/// `~/.local/bin` 等用户目录都不在其中，而用户终端里它们都在。
///
/// 因此这里通过**登录 shell** 解析用户交互式终端真正使用的 `PATH`，
/// 让「装完立即可用」的判断与用户实际体验一致。
public enum CLIPathResolver {
    /// 交互式登录 shell 的解析超时（秒）。
    ///
    /// 交互式 shell 需要加载用户的 `.zshrc`，通常在 1~2 秒；
    /// 超时后回落到非交互式登录 shell。
    private static let interactiveTimeout: TimeInterval = 3
    /// 非交互式登录 shell 的解析超时（秒）。
    private static let loginTimeout: TimeInterval = 2

    /// 解析用户终端的 `PATH` 条目。
    ///
    /// 解析顺序：
    /// 1. 交互式登录 shell（`-l -i`）—— 与用户终端里的 shell 一致；
    /// 2. 登录 shell（`-l`）—— 交互式不可用或超时时的回落；
    /// 3. 当前进程的 `PATH` —— 最后的兜底。
    ///
    /// - Parameters:
    ///   - environment: 环境变量字典（用于读取 `SHELL` 与 `PATH`）。
    ///   - fileManager: 文件管理器（用于定位可用的 shell）。
    /// - Returns: `PATH` 条目列表（已去除空项，保持原始顺序）。
    public static func resolveUserPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [String] {
        if let shell = launchShellPath(environment: environment, fileManager: fileManager) {
            let interactive = pathEntries(
                fromShell: shell,
                arguments: ["-l", "-i", "-c", "printenv PATH"],
                timeout: interactiveTimeout
            )
            if !interactive.isEmpty {
                return interactive
            }

            let login = pathEntries(
                fromShell: shell,
                arguments: ["-l", "-c", "printenv PATH"],
                timeout: loginTimeout
            )
            if !login.isEmpty {
                return login
            }
        }

        return parsePathEntries(environment["PATH"] ?? "")
    }

    /// 进程内缓存的用户 `PATH`（首次访问时解析一次）。
    ///
    /// - Note: 首次访问会同步解析（最长约 5 秒）。调用方应尽量在后台线程
    ///   预热（见 ``prewarm()``），避免阻塞主线程。
    public static let cachedUserPath: [String] = resolveUserPath()

    /// 预热缓存。建议在后台线程调用，让首次解析不发生在用户可见的时刻。
    public static func prewarm() {
        _ = cachedUserPath
    }

    // MARK: - Private Helpers

    /// 定位可用于解析 `PATH` 的 shell。
    private static func launchShellPath(
        environment: [String: String],
        fileManager: FileManager
    ) -> String? {
        let candidates = [
            environment["SHELL"],
            "/bin/zsh",
            "/bin/bash",
        ]
        for candidate in candidates {
            guard let candidate, candidate.hasPrefix("/") else { continue }
            guard fileManager.isExecutableFile(atPath: candidate) else { continue }
            return candidate
        }
        return nil
    }

    /// 运行 shell 并解析出其中的 `PATH`。
    private static func pathEntries(
        fromShell shell: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> [String] {
        guard let output = captureOutput(
            executablePath: shell,
            arguments: arguments,
            timeout: timeout
        ) else { return [] }

        return absolutePathEntries(fromShellOutput: output)
    }

    /// 拆分 `PATH` 字符串为条目列表。
    internal static func parsePathEntries(_ path: String) -> [String] {
        path
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
    }

    /// 从 shell 输出中解析出 `PATH` 的绝对路径条目。
    ///
    /// `printenv PATH` 的值位于输出末尾（rc 噪声在它之前）。`PATH` 可能以相对
    /// 条目（`.`、`foo`）或空条目开头，因此**不能假设整行以 "/" 开头**；从最后
    /// 一行往前找首个含绝对条目的行，拆分后只保留绝对路径（#144）。相对条目
    /// 依赖当前目录、对「安装位置」无意义，按设计忽略。
    internal static func absolutePathEntries(fromShellOutput output: String) -> [String] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines.reversed() {
            let absolute = parsePathEntries(String(line)).filter { $0.hasPrefix("/") }
            if !absolute.isEmpty { return absolute }
        }
        return []
    }

    /// 执行命令并捕获 stdout，超时后强制结束。
    ///
    /// stdout 在独立线程读取，避免 rc 输出量大时管道写满导致子进程卡死。
    private static func captureOutput(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let collector = OutputCollector()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue(label: "com.coffic.lumi.kitlumicli.shell-output").async {
            collector.set(pipe.fileHandleForReading.readDataToEndOfFile())
            semaphore.signal()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(10_000)
        }

        if process.isRunning {
            process.terminate()
            let killDeadline = Date().addingTimeInterval(0.5)
            while process.isRunning && Date() < killDeadline {
                usleep(10_000)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            return nil
        }

        // 进程已退出，管道写端关闭；读取线程通常立即结束，设有界等待兜底。
        _ = semaphore.wait(timeout: .now() + 1)
        guard let data = collector.get() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// 线程安全的数据收集盒。
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func set(_ value: Data) {
        lock.lock()
        defer { lock.unlock() }
        data = value
    }

    func get() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
