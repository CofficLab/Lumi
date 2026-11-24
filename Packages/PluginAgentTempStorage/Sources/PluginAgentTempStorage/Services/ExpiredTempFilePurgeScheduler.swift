import Foundation

/// 过期临时文件的启动/定时清理调度器（#509）。
///
/// 此前 `purgeExpiredFiles` 只挂在 write/read/list 工具调用上：没有任何
/// Agent 工具操作时，过期文件会无限滞留，与工具描述「保留期后自动删除」
/// 的承诺不符。调度器在启动后立即清理一次，之后每个周期重复；`stop`
/// 取消后续清理。
@MainActor
final class ExpiredTempFilePurgeScheduler {
    private let interval: Duration
    private let purge: @Sendable () async throws -> Void
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - interval: 两次清理之间的间隔。
    ///   - purge: 单次清理动作。抛错由调用方在闭包内记录，调度器不重试。
    init(interval: Duration, purge: @escaping @Sendable () async throws -> Void) {
        self.interval = interval
        self.purge = purge
    }

    /// 启动调度：立即清理一次，随后每个周期重复。重复调用会先取消前一轮。
    func start() {
        stop()
        task = Task { [purge, interval] in
            await Self.runPurge(purge)
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                if Task.isCancelled { break }
                await Self.runPurge(purge)
            }
        }
    }

    /// 取消后续清理。已经在执行中的单次清理会自然完成。
    func stop() {
        task?.cancel()
        task = nil
    }

    private static func runPurge(_ purge: @Sendable () async throws -> Void) async {
        try? await purge()
    }
}
