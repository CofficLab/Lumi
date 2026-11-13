import Foundation

/// 条件等待的轮询循环。
///
/// 用于「轮询真实状态，条件一成立立刻返回」这类等待，
/// 避免 LLM 用固定 sleep 猜时间。
///
/// - Important: 休眠**不能**吞掉取消错误。
///   任务被取消后 `Task.sleep` 会立即抛错返回，吞掉它会让循环立刻进入下一轮：
///   不需要挂起等待的判定分支就变成了忙轮询，而且要一直空转到超时才结束
///   （见 issue #418）。
struct BrowserWaitLoop {
    /// 两次判定之间的休眠间隔。
    let pollInterval: TimeInterval

    /// 等待截止时刻。
    let deadline: Date

    /// 跑一轮等待循环。
    ///
    /// - Parameter isSatisfied: 条件判定，返回 true 表示条件成立。
    /// - Returns: true 表示条件成立，false 表示等到超时仍未成立。
    /// - Throws: `CancellationError`（任务被取消时立刻抛出并向上传播）。
    func run(isSatisfied: @Sendable () async throws -> Bool) async throws -> Bool {
        while Date() < deadline {
            try Task.checkCancellation()

            if try await isSatisfied() {
                return true
            }

            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return false
    }
}
