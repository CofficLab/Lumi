import Foundation
import SwiftUI

/// 会话迁移进度状态
///
/// 一个 `@MainActor ObservableObject` 单例,由后台迁移任务(`ConversationLegacyMigration`)
/// 更新,状态栏 popover 视图(`ConversationMigrationPopoverView`)通过 `@ObservedObject` 订阅。
/// 迁移完成(或未启动)时 `isActive` 为 false,状态栏项被 unregister 隐藏。
///
/// 与消息迁移不同:会话迁移是单次批量导入,没有逐项循环进度,故只需 read/imported 计数 + 阶段。
@MainActor
public final class ConversationMigrationProgressStore: ObservableObject {
    public static let shared = ConversationMigrationProgressStore()

    /// 迁移阶段
    public enum Phase: Equatable {
        case idle
        case running
        case completed
        case failed
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var readCount: Int = 0
    @Published public private(set) var importedCount: Int = 0
    @Published public private(set) var startedAt: Date?

    /// 是否正在迁移(状态栏据此决定显隐)
    public var isActive: Bool { phase == .running }

    private init() {}

    // MARK: - 由 ConversationLegacyMigration 调用的更新方法

    /// 标记迁移开始
    func start() {
        phase = .running
        readCount = 0
        importedCount = 0
        startedAt = Date()
    }

    /// 设置读取到的会话数
    func setReadCount(_ count: Int) {
        readCount = count
    }

    /// 设置实际导入的会话数
    func setImportedCount(_ count: Int) {
        importedCount = count
    }

    /// 标记迁移完成
    func finish() {
        phase = .completed
    }

    /// 标记迁移失败
    func fail() {
        phase = .failed
    }
}
