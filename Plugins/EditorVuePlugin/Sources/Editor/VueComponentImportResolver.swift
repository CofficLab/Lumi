import Foundation
import EditorService

/// Vue 组件自动导入补全贡献器
///
/// 当用户在 `.vue` 文件中输入组件名时（如 `<MyBut`），
/// 提供项目中组件的补全建议，并附带文件路径信息。
///
/// 实现策略：
/// 1. 使用 VueProjectScanner 扫描项目中的 `.vue` 文件
/// 2. 过滤匹配输入前缀的组件
/// 3. 提供 PascalCase 和 kebab-case 两种名称补全
@MainActor
final class VueComponentImportResolver: SuperEditorCompletionContributor {
    let id = "builtin.vue.component-import"

    /// 扫描缓存（projectPath → [ComponentEntry]）
    /// 避免每次补全都重新扫描文件系统
    private static let maxCachedProjects = 20
    private static var scanCache: [String: [VueProjectScanner.ComponentEntry]] = [:]
    private static var cacheTimestamp: [String: Date] = [:]
    private static var cacheKeysByRecency: [String] = []
    private static let cacheTimeout: TimeInterval = 30 // 30 秒缓存

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard VueKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        // 只在模板上下文中提供组件补全
        guard shouldProvideComponentCompletion(prefix: prefix) else { return [] }

        let components = await scanCurrentProject()
        guard !components.isEmpty else { return [] }

        // 过滤匹配前缀的组件
        let normalizedPrefix = prefix.lowercased()
        let matches = components.filter { entry in
            let pascalLower = entry.name.lowercased()
            let kebab = VueProjectScanner.pascalToKebab(entry.name)
            return pascalLower.hasPrefix(normalizedPrefix) || kebab.hasPrefix(normalizedPrefix)
        }

        return matches.map { entry in
            EditorCompletionSuggestion(
                label: entry.name,
                insertText: entry.name,
                detail: "Import from '\(entry.relativePath)'",
                priority: 920
            )
        }
    }

    // MARK: - 私有方法

    /// 判断是否应该提供组件补全
    private func shouldProvideComponentCompletion(prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespaces)

        // 组件名以大写字母开头（PascalCase 约定）
        if let first = trimmed.first, first.isUppercase {
            return true
        }

        // 以 `<` 开头
        if trimmed.hasPrefix("<") {
            return true
        }

        return false
    }

    /// 扫描当前项目的组件，带缓存
    ///
    /// 注意：由于无法直接获取项目路径，此方法返回空列表。
    /// 在实际使用中，应通过 EditorState 获取项目根路径后调用
    /// `scan(projectPath:)` 方法来填充缓存。
    private func scanCurrentProject() async -> [VueProjectScanner.ComponentEntry] {
        Self.removeExpiredCacheEntries()

        // 返回所有缓存的组件
        var allComponents: [VueProjectScanner.ComponentEntry] = []
        for (path, entries) in Self.scanCache {
            if let timestamp = Self.cacheTimestamp[path],
               Date().timeIntervalSince(timestamp) < Self.cacheTimeout {
                allComponents.append(contentsOf: entries)
            }
        }
        return allComponents
    }
}

// MARK: - 缓存辅助（非 MainActor）

extension VueComponentImportResolver {
    /// 预扫描并缓存项目组件
    /// 应在打开 `.vue` 文件时由外部调用
    nonisolated static func precache(projectPath: String) {
        Task.detached { @MainActor in
            let entries = VueProjectScanner.scan(projectPath: projectPath)
            scanCache[projectPath] = entries
            cacheTimestamp[projectPath] = Date()
            markRecentlyUsed(projectPath)
            trimCacheIfNeeded()
        }
    }

    /// 获取缓存的扫描结果
    nonisolated static func cachedEntries(for projectPath: String) -> [VueProjectScanner.ComponentEntry]? {
        // 由于 scanCache 是 @MainActor，需要在 MainActor 上读取
        // 这里提供一个轻量级读取方式
        return nil // 由 precache 在后台填充，MainActor 侧读取
    }

    /// 清除缓存
    nonisolated static func clearCache(for projectPath: String) {
        Task.detached { @MainActor in
            removeCache(for: projectPath)
        }
    }

    private static func markRecentlyUsed(_ projectPath: String) {
        cacheKeysByRecency.removeAll { $0 == projectPath }
        cacheKeysByRecency.append(projectPath)
    }

    private static func trimCacheIfNeeded() {
        while cacheKeysByRecency.count > maxCachedProjects {
            let oldestProjectPath = cacheKeysByRecency.removeFirst()
            scanCache.removeValue(forKey: oldestProjectPath)
            cacheTimestamp.removeValue(forKey: oldestProjectPath)
        }
    }

    private static func removeExpiredCacheEntries() {
        let now = Date()
        let expiredProjectPaths = cacheTimestamp.compactMap { projectPath, timestamp in
            now.timeIntervalSince(timestamp) >= cacheTimeout ? projectPath : nil
        }
        expiredProjectPaths.forEach(removeCache(for:))
    }

    private static func removeCache(for projectPath: String) {
        scanCache.removeValue(forKey: projectPath)
        cacheTimestamp.removeValue(forKey: projectPath)
        cacheKeysByRecency.removeAll { $0 == projectPath }
    }
}
