import Foundation
import KitShell

/// Auto Push 配置：描述「在什么条件下自动推送」。
public struct AutoPushConfig: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    public var intervalSeconds: Int = 60
    /// 触发推送的最低未推送提交数（0 表示任意未推送就触发）。
    public var minUnpushedCommits: Int = 0
    /// 远端名称，缺省时使用当前分支的 upstream。
    public var remote: String = "origin"
    /// 是否仅在「工作区干净」时推送。
    public var requireCleanWorkingTree: Bool = true

    public init() {}

    public init(
        enabled: Bool = false,
        intervalSeconds: Int = 60,
        minUnpushedCommits: Int = 0,
        remote: String = "origin",
        requireCleanWorkingTree: Bool = true
    ) {
        self.enabled = enabled
        self.intervalSeconds = intervalSeconds
        self.minUnpushedCommits = minUnpushedCommits
        self.remote = remote
        self.requireCleanWorkingTree = requireCleanWorkingTree
    }

    public static let `default` = AutoPushConfig()
}

/// Auto Push 服务：基于轮询的简易调度器。
///
/// 启动后按 `intervalSeconds` 检查仓库：若存在未推送提交
/// 且满足其它条件，便调用 `git push`。
@MainActor
public final class AutoPushService: ObservableObject {
    public static let shared = AutoPushService()

    @Published public private(set) var isRunning: Bool = false
    @Published public var config: AutoPushConfig = .default
    @Published public private(set) var lastRunAt: Date?
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastInfo: String?

    private var timer: Task<Void, Never>?
    private var projectPath: String = ""

    public init() {}

    public func configure(projectPath: String) {
        self.projectPath = projectPath
    }

    public func start() {
        guard timer == nil, config.enabled else { return }
        let interval = max(5, config.intervalSeconds)
        isRunning = true
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    public func tick() async {
        guard config.enabled, !projectPath.isEmpty else { return }
        do {
            // 1. 工作区检查
            if config.requireCleanWorkingTree {
                let dirty = await hasUncommittedChanges(at: projectPath)
                if dirty { return }
            }
            // 2. 未推送提交数
            let unpushed = try await unpushedCount(at: projectPath)
            if unpushed < config.minUnpushedCommits { return }
            // 3. 推送
            try await push(at: projectPath, remote: config.remote)
            lastRunAt = Date()
            lastInfo = "Pushed \(unpushed) commit(s) to \(config.remote)"
            lastError = nil
        } catch {
            lastError = "Auto-push failed: \(error.localizedDescription)"
        }
    }

    // MARK: - helpers

    private func hasUncommittedChanges(at path: String) async -> Bool {
        let r = try? await ShellExecutor.execute(
            "git status --porcelain",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
        return !(r?.stdout.isEmpty ?? true)
    }

    private func unpushedCount(at path: String) async throws -> Int {
        let r = try await ShellExecutor.execute(
            "git rev-list --count @{u}..HEAD",
            options: ShellOptions(workingDirectory: path, throwsOnError: false)
        )
        return Int(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func push(at path: String, remote: String) async throws {
        _ = try await ShellExecutor.execute(
            "git push \(remote)",
            options: ShellOptions(workingDirectory: path, timeout: 120)
        )
    }
}
