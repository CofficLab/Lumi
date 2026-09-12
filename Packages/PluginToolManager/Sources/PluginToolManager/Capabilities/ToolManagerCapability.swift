import Foundation
import KitAgentTool
import ProviderToolManager

/// 工具管理器设置页需要的最小外部操作集合。
///
/// 收敛 `ToolManagerProviding` 与 `ToolCallRecordStore`，View 与 ViewModel
/// 都不再直接接触 manager / store。
@MainActor
protocol ToolManagerCapability {
    /// 按插件分组的所有已注册工具。
    var toolsGroupedByPlugin: [(pluginID: String, tools: [any SuperAgentTool])] { get }

    /// 是否已配置记录存储（决定执行日志 / 统计 Tab 是否可用）。
    var hasLogStore: Bool { get }

    /// 记录存储目录（用于打开数据目录）。
    var storeDirectory: URL? { get }

    /// 记录总数。
    func countRecords() async -> Int

    /// 分页拉取一页记录（按创建时间倒序；游标为「早于某条」语义）。
    func fetchLogPage(
        limit: Int,
        beforeCreatedAt: Date?,
        beforeID: String?
    ) async -> [ToolCallRecord]
}

/// 默认实现：持有 manager 与 store，把最小操作转发给它们。
@MainActor
final class ToolManagerCapabilityAdapter: ToolManagerCapability {
    private let manager: any ToolManagerProviding
    private let store: ProviderToolManager.ToolCallRecordStore?

    init(
        manager: any ToolManagerProviding,
        store: ProviderToolManager.ToolCallRecordStore?
    ) {
        self.manager = manager
        self.store = store
    }

    var toolsGroupedByPlugin: [(pluginID: String, tools: [any SuperAgentTool])] {
        manager.toolsGroupedByPlugin()
    }

    var hasLogStore: Bool {
        store != nil
    }

    var storeDirectory: URL? {
        store?.directory
    }

    func countRecords() async -> Int {
        await store?.count() ?? 0
    }

    func fetchLogPage(
        limit: Int,
        beforeCreatedAt: Date?,
        beforeID: String?
    ) async -> [ToolCallRecord] {
        await store?.fetchPage(
            limit: limit,
            beforeCreatedAt: beforeCreatedAt,
            beforeID: beforeID
        ) ?? []
    }
}
