import Combine
import Foundation
import PluginIdleTime
import SwiftUI

private final class AppIdleTimeTimerHolder: @unchecked Sendable {
    var timer: Timer?

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

/// 空闲时间 ViewModel
///
/// 数据来源：`IdleTimePlugin` 内部的 `IdleTimeService` 通过
/// `NotificationCenter` 推送快照变更，VM 在主线程更新 `@Published` 属性。
///
/// **生命周期约束：**
/// - 必须且只能在 ``RootContainer`` 中初始化（全局唯一实例）。
/// - 由 ``RootView`` 通过 `.environmentObject()` 注入到 SwiftUI 环境。
///
/// **插件获取方式：**
/// - 在视图层通过 `@EnvironmentObject` 获取（如 `@EnvironmentObject var idleTimeVM: AppIdleTimeVM`）。
@MainActor
final class AppIdleTimeVM: ObservableObject {

    // MARK: - Published State

    /// 当前推断的休息窗口
    @Published private(set) var restWindow: PluginIdleTime.RestWindow?

    /// 置信度标签
    @Published private(set) var confidenceLabel: PluginIdleTime.IdleConfidenceLabel = .learning

    /// 当前是否处于推断的休息时间段
    @Published private(set) var isInRestWindow: Bool = false

    /// 24 小时活动热力图分数（48 个桶）
    @Published private(set) var activityScores: [Double] = []

    /// 完整推断快照（供需要详细数据的消费者使用）
    @Published private(set) var snapshot: PluginIdleTime.IdleInferenceSnapshot?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private nonisolated let refreshTimerHolder = AppIdleTimeTimerHolder()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        subscribeToSnapshotChanges()
        schedulePeriodicRefresh()
    }

    deinit {
        refreshTimerHolder.invalidate()
        refreshTask?.cancel()
    }

    // MARK: - Subscription

    private func subscribeToSnapshotChanges() {
        NotificationCenter.default.publisher(for: .idleTimeSnapshotDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshFromService()
            }
            .store(in: &cancellables)
    }

    private func schedulePeriodicRefresh() {
        guard refreshTimerHolder.timer == nil else { return }

        refreshFromService()

        refreshTimerHolder.timer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromService()
            }
        }
    }

    private func refreshFromService() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil }

            let snapshot = await IdleTimeService.shared.currentSnapshot()

            self.snapshot = snapshot
            self.restWindow = snapshot.restWindow
            self.activityScores = snapshot.bucketScores

            if let window = snapshot.restWindow {
                self.confidenceLabel = PluginIdleTime.IdleConfidenceLabel.label(
                    for: window.confidence,
                    source: window.source
                )
                self.isInRestWindow = window.contains(Date())
                    && window.source != .defaultFallback
                    && window.confidence >= 0.70
            } else {
                self.confidenceLabel = .learning
                self.isInRestWindow = false
            }
        }
    }
}
