import Foundation

/// Git 分支监听器
///
/// 通过 DispatchSource 监听 `.git/HEAD` 文件变化，实时检测 Git 分支切换。
/// 支持多路径监听、防抖和事件去重。
///
/// ## 线程安全
///
/// 整个类型标记为 `@MainActor`，所有属性访问和回调都在主线程上执行。
/// DispatchSource 的 event handler 通过 `Task { @MainActor }` 跳回主线程，
/// 避免后台队列直接访问 `@MainActor` 隔离的成员。
///
/// ## 使用示例
///
/// ```swift
/// @StateObject private var monitor = GitBranchMonitor()
///
/// monitor.onBranchChange { projectPath, newBranch in
///     print("分支变化: \(projectPath) -> \(newBranch ?? "detached")")
/// }
/// monitor.startMonitoring(projectPath: "/path/to/project")
/// ```
@MainActor
public final class GitBranchMonitor: ObservableObject {
    // MARK: - Types

    /// 分支变化回调
    public typealias BranchChangeCallback = @Sendable (_ projectPath: String, _ branch: String?) -> Void

    /// 监听器内部状态
    struct MonitorState {
        let fileDescriptor: Int32
        let dispatchSource: DispatchSourceFileSystemObject?
        let lastBranch: String?
        let lastUpdateTime: Date
    }

    // MARK: - Properties

    /// 项目路径 → 监听器状态
    var monitors: [String: MonitorState] = [:]

    /// 分支变化回调列表
    var callbacks: [BranchChangeCallback] = []

    /// 防抖延迟（秒）
    public var debounceDelay: TimeInterval = 0.3

    /// 防抖任务
    var debounceTasks: [String: Task<Void, Never>] = [:]

    /// 是否启用详细日志
    public var verbose: Bool = false

    // MARK: - Initialization

    public init(verbose: Bool = false) {
        self.verbose = verbose
    }

    // MARK: - Public API

    /// 添加分支变化回调
    public func onBranchChange(_ callback: @escaping BranchChangeCallback) {
        callbacks.append(callback)
    }

    /// 开始监听指定项目路径的分支变化
    public func startMonitoring(projectPath: String) {
        // 如果已经在监听，先停止旧的
        if monitors[projectPath] != nil {
            stopMonitoring(projectPath: projectPath)
        }

        let headPath = Self.headPath(for: projectPath)

        // 检查 .git/HEAD 文件是否存在
        guard FileManager.default.fileExists(atPath: headPath) else {
            if verbose {
                print("[GitBranchMonitor] ⏭️ 跳过非 Git 项目: \(projectPath)")
            }
            return
        }

        // 打开文件描述符
        let fileDescriptor = Darwin.open(headPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[GitBranchMonitor] ❌ 无法打开文件描述符: \(headPath)")
            return
        }

        // 创建 DispatchSource，在后台队列上监听文件事件
        let queue = DispatchQueue.global(qos: .userInitiated)
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )

        // 设置事件处理器
        // DispatchSource 在后台队列上运行，通过 Task { @MainActor } 跳回主线程。
        // 不能用 { [weak self] in Task { await self?.... } } 因为 self 是 @MainActor 的，
        // 在后台线程捕获 self 会触发 actor isolation 检查。
        dispatchSource.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFileChange(projectPath: projectPath)
            }
        }

        // 设置取消处理器（纯 C 调用，关闭文件描述符，不涉及 Actor 隔离）
        dispatchSource.setCancelHandler {
            Darwin.close(fileDescriptor)
        }

        // 启动监听
        dispatchSource.resume()

        // 读取当前分支并保存状态
        let currentBranch = Self.parseHeadFile(at: headPath)

        monitors[projectPath] = MonitorState(
            fileDescriptor: fileDescriptor,
            dispatchSource: dispatchSource,
            lastBranch: currentBranch,
            lastUpdateTime: Date()
        )

        if verbose {
            print("[GitBranchMonitor] 🎯 开始监听: \(projectPath) (当前分支: \(currentBranch ?? "nil"))")
        }
    }

    /// 停止监听指定项目路径
    public func stopMonitoring(projectPath: String) {
        guard let state = monitors[projectPath] else { return }

        // 取消防抖任务
        debounceTasks[projectPath]?.cancel()
        debounceTasks.removeValue(forKey: projectPath)

        // 取消 DispatchSource（cancel handler 会关闭 fd）
        state.dispatchSource?.cancel()

        monitors.removeValue(forKey: projectPath)

        if verbose {
            print("[GitBranchMonitor] ⏹️ 停止监听: \(projectPath)")
        }
    }

    /// 停止所有监听
    public func stopAll() {
        let paths = monitors.keys.map { $0 }
        for path in paths {
            stopMonitoring(projectPath: path)
        }
        callbacks.removeAll()
    }

    /// 当前正在监听的项目路径列表
    public var monitoredPaths: [String] {
        Array(monitors.keys)
    }

    /// 获取指定项目的当前分支（从缓存中读取）
    public func currentBranch(for projectPath: String) -> String? {
        monitors[projectPath]?.lastBranch
    }

    // MARK: - Internal (testable)

    /// 处理文件变化事件（在 @MainActor 上下文调用）
    func handleFileChange(projectPath: String) {
        // 取消防抖任务
        debounceTasks[projectPath]?.cancel()

        // 创建新的防抖任务（继承 @MainActor 上下文）
        debounceTasks[projectPath] = Task { [weak self] in
            guard let self = self else { return }

            // 防抖等待
            try? await Task.sleep(nanoseconds: UInt64(self.debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            let headPath = Self.headPath(for: projectPath)
            let newBranch = Self.parseHeadFile(at: headPath)
            let lastBranch = self.monitors[projectPath]?.lastBranch

            // 仅在分支实际变化时才通知
            guard newBranch != lastBranch else { return }

            // 更新状态
            if let state = self.monitors[projectPath] {
                self.monitors[projectPath] = MonitorState(
                    fileDescriptor: state.fileDescriptor,
                    dispatchSource: state.dispatchSource,
                    lastBranch: newBranch,
                    lastUpdateTime: Date()
                )
            }

            // 通知回调
            for callback in self.callbacks {
                callback(projectPath, newBranch)
            }

            if self.verbose {
                print("[GitBranchMonitor] 🔄 分支变化: \(projectPath) (\(lastBranch ?? "nil") -> \(newBranch ?? "nil"))")
            }
        }
    }

    // MARK: - Static Helpers (pure functions, easily testable)

    /// 构造 .git/HEAD 文件路径
    public static func headPath(for projectPath: String) -> String {
        "\(projectPath)/.git/HEAD"
    }

    /// 解析 .git/HEAD 文件内容，提取分支名称
    ///
    /// 支持格式：
    /// - `ref: refs/heads/main` → `"main"`
    /// - `abc123...`（40 位十六进制）→ `nil`（分离头指针）
    /// - 文件不存在或无法读取 → `nil`
    public static func parseHeadFile(at path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return parseHeadContent(content)
    }

    /// 解析 HEAD 文件内容字符串
    ///
    /// - Parameter content: HEAD 文件的原始内容
    /// - Returns: 分支名称，或 `nil` 表示分离头指针 / 无法解析
    public static func parseHeadContent(_ content: String) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 标准格式: "ref: refs/heads/<branch>"
        if trimmed.hasPrefix("ref: refs/heads/") {
            let branch = String(trimmed.dropFirst("ref: refs/heads/".count))
            return branch.isEmpty ? nil : branch
        }

        // 分离头指针: 40 位十六进制 commit hash
        if trimmed.count == 40 && trimmed.allSatisfy(\.isHexDigit) {
            return nil
        }

        return nil
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}
