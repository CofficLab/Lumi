import Combine
import Foundation
import SwiftUI

/// 空闲时间 ViewModel，通过环境注入供所有插件和视图使用。
///
/// 数据来源：`IdleTimePlugin` 内部的 `IdleTimeService` 通过
/// `NotificationCenter` 推送快照变更，VM 在主线程更新 `@Published` 属性。
///
/// 其他插件只需：
/// ```swift
/// @EnvironmentObject var idleTimeVM: AppIdleTimeVM
/// ```
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有，不通过 `.environmentObject()` 注入。
/// 插件按需直接访问 `RootContainer.shared.idleTimeVM`。
@MainActor
final class AppIdleTimeVM: ObservableObject {

    // MARK: - Published State

    /// 当前推断的休息窗口
    @Published private(set) var restWindow: RestWindow?

    /// 置信度标签
    @Published private(set) var confidenceLabel: IdleConfidenceLabel = .learning

    /// 当前是否处于推断的休息时间段
    @Published private(set) var isInRestWindow: Bool = false

    /// 24 小时活动热力图分数（48 个桶）
    @Published private(set) var activityScores: [Double] = []

    /// 完整推断快照（供需要详细数据的消费者使用）
    @Published private(set) var snapshot: IdleInferenceSnapshot?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    // MARK: - Init

    init() {
        subscribeToSnapshotChanges()
        schedulePeriodicRefresh()
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
        refreshFromService()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromService()
            }
        }
    }

    private func refreshFromService() {
        Task {
            let snapshot = await IdleTimeService.shared.currentSnapshot()

            self.snapshot = snapshot
            self.restWindow = snapshot.restWindow
            self.activityScores = snapshot.bucketScores

            if let window = snapshot.restWindow {
                self.confidenceLabel = IdleConfidenceLabel.label(
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
