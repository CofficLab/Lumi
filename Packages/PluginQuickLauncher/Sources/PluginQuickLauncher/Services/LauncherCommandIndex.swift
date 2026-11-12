import Foundation

/// 启动器命令搜索索引
///
/// 缓存命令 DTO 与归一化搜索键，只在命令来源版本变化时重建；
/// 检索时拿到足够结果即停止，避免每次按键都对全量命令做 DTO 重建与匹配。
@MainActor
final class LauncherCommandIndex {
    // MARK: - Types

    /// 单条命令的检索条目
    private struct Entry {
        let groupName: String
        let normalizedGroupName: String
        let item: LauncherCommandItem
        let normalizedTitle: String
    }

    // MARK: - State

    /// 展平后的命令条目，按命令组注册顺序排列
    private var entries: [Entry] = []
    /// 已缓存的来源版本；与 `LauncherBridge.commandGroupsVersion` 不一致时重建。
    private var cachedVersion: UInt64?

    // MARK: - Cache

    /// 来源版本变化后重建索引
    private func ensureFresh() {
        let version = LauncherBridge.commandGroupsVersion
        guard cachedVersion != version else { return }
        cachedVersion = version

        let groups = LauncherBridge.commandGroupsProvider?() ?? []
        entries = groups.flatMap { group in
            let normalizedGroupName = group.name.lowercased()
            return group.items.map { item in
                Entry(
                    groupName: group.name,
                    normalizedGroupName: normalizedGroupName,
                    item: item,
                    normalizedTitle: item.title.lowercased()
                )
            }
        }
    }

    // MARK: - Search

    /// 搜索命令，最多返回 limit 条
    ///
    /// 与既有语义一致：按命令组注册顺序取前 limit 条匹配项。
    func search(matching query: String, limit: Int) -> [LauncherResult] {
        ensureFresh()
        guard !query.isEmpty, limit > 0 else { return [] }
        let lowered = query.lowercased()

        var found: [LauncherResult] = []
        for entry in entries {
            guard entry.normalizedTitle.contains(lowered)
                || entry.normalizedGroupName.contains(lowered) else { continue }
            found.append(LauncherResult(command: entry.item, groupName: entry.groupName))
            // 结果条数已够，不再继续扫描剩余命令。
            if found.count >= limit { break }
        }
        return found
    }

    /// 按结果 id 找到并执行原始命令；找到并执行返回 true。
    @discardableResult
    func execute(resultID: String) -> Bool {
        ensureFresh()
        let prefix = "command:"
        guard resultID.hasPrefix(prefix) else { return false }
        let payload = String(resultID.dropFirst(prefix.count))
        for entry in entries where "\(entry.groupName)/\(entry.item.id)" == payload {
            entry.item.action()
            return true
        }
        return false
    }
}
