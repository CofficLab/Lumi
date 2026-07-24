import Foundation
import SwiftUI

/// 消息迁移进度状态
///
/// 一个 `@MainActor ObservableObject` 单例,由后台迁移任务(`MessageLegacyMigration`)
/// 在循环里更新,状态栏视图(`MessageMigrationStatusBarView`)通过 `@ObservedObject` 订阅,
/// 进度变化时 UI 自动刷新。迁移完成(或未启动)时 `isActive` 为 false,状态栏项自动隐藏。
@MainActor
public final class MessageMigrationProgressStore: ObservableObject {
    public static let shared = MessageMigrationProgressStore()

    /// 迁移阶段
    public enum Phase: Equatable {
        case idle
        case running
        case completed
        case failed
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var totalConversations: Int = 0
    @Published public private(set) var processedConversations: Int = 0
    @Published public private(set) var importedMessages: Int = 0
    @Published public private(set) var startedAt: Date?

    /// 是否正在迁移(状态栏据此决定显隐)
    public var isActive: Bool { phase == .running }

    /// 进度比例 0...1(总数为 0 时返回 0)
    public var fraction: Double {
        guard totalConversations > 0 else { return 0 }
        return Double(processedConversations) / Double(totalConversations)
    }

    private init() {}

    // MARK: - 由 MessageLegacyMigration 调用的更新方法

    /// 标记迁移开始,初始化计数
    func start(totalConversations: Int) {
        phase = .running
        self.totalConversations = totalConversations
        processedConversations = 0
        importedMessages = 0
        startedAt = Date()
    }

    /// 处理完一个会话后累加
    func tick(importedDelta: Int) {
        processedConversations += 1
        importedMessages += importedDelta
    }

    /// 标记迁移完成
    func finish() {
        phase = .completed
    }

    /// 标记迁移失败(不阻塞,下次启动可重试 —— 由 marker 机制控制)
    func fail() {
        phase = .failed
    }
}
