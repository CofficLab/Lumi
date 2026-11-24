import Foundation

extension VM {
    /// 执行一个需要展示加载状态的异步操作。
    ///
    /// 该方法是可重入的：用 `busyOperationCount` 记录正在进行的操作数，
    /// 由**首个**操作重置错误信息并启动 500ms 遮罩延时，由**最后一个**
    /// 操作取消延时并关闭遮罩。
    ///
    /// 这样同一用户动作串起的多个请求（例如切换 App 时的版本列表、
    /// 本地化、构建与提交状态）只表现为一次连续的 loading，而不是中途
    /// 被内层调用掐断、反复闪烁。
    func runBusy(forceRefresh: Bool = false, _ operation: () async throws -> Void) async {
        let startTime = ContinuousClock.now
        busyOperationCount += 1
        let isFirstOperation = busyOperationCount == 1

        // force refresh 覆盖整个重叠窗口（#437）：首个操作记住原策略并切到
        // networkOnly，最后一个操作恢复。此前每个操作各自保存/还原共享的
        // fetchPolicy——先结束者提前还原策略，后结束者把 networkOnly 永久
        // 留在 client 上。
        if forceRefresh {
            if busyForceRefreshCount == 0 {
                busyPreviousFetchPolicy = client.fetchPolicy
            }
            busyForceRefreshCount += 1
            client.fetchPolicy = .networkOnly
        }

        if isFirstOperation {
            isBusy = false
            errorMessage = nil
            busyOverlayDelayTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: Self.loadingOverlayDelay)
                    isBusy = true
                } catch {
                    // Cancelled when the operation finishes before the delay elapses.
                }
            }
        }

        defer {
            busyOperationCount -= 1
            if forceRefresh {
                busyForceRefreshCount -= 1
                if busyForceRefreshCount == 0 {
                    client.fetchPolicy = busyPreviousFetchPolicy
                }
            }
            if busyOperationCount == 0 {
                busyOverlayDelayTask?.cancel()
                busyOverlayDelayTask = nil
                isBusy = false
            }
        }

        do {
            try await operation()
        } catch {
            Self.logger.error("\(self.t)operation failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        Self.logger.info("\(self.t)runBusy completed in \((ContinuousClock.now - startTime).formatted()) (active: \(self.busyOperationCount))")
    }
}
