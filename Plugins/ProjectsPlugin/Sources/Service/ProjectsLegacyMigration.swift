import Foundation
import LumiKernel
import SuperLogKit
import os

/// v4 历史项目迁移服务
///
/// 把 v4 的项目列表(纯 JSON 文件,非数据库)迁移到 v5。设计与会话/消息迁移一致:
/// 幂等(marker + 按 path 去重)、吞错(绝不向上抛,避免阻塞 onReady)、策略开关。
///
/// # 实现要点
/// - v4 与 v5 的项目存储机制完全相同(`ProjectsStore` + JSON 文件),故直接复用
///   `ProjectsStore` 读 v4 目录,无需走 `LegacyDataProviding`(那是给数据库用的)。
/// - 迁移时机:必须在 `ProjectsViewModel` 初始化**之前**完成 —— viewModel init 时
///   会 loadProjects,此时 v5 的 projects.json 应已含合并后的数据。
/// - language 字段:v4 没有,迁移时留 nil,后续由 v5 的 ProjectLanguageDetector 探测补上。
@MainActor
public struct ProjectsLegacyMigration: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated public static let emoji = "📁"

    /// 迁移策略(语义同 ConversationLegacyMigration / MessageLegacyMigration)
    public enum MigrationPolicy {
        case once
        case always
    }

    /// 迁移策略开关。测试期 `.always`,上线前改回 `.once`。
    public static var policy: MigrationPolicy = .always

    /// 迁移标记的 UserDefaults key
    private static let migrationMarkerKey = "lumi.v4_migration.projects.completed"

    /// v4 数据目录名(Debug/Release 与 StoragePlugin 命名一致)
    private static let v4DirectoryName = "db_production_v4"
    private static let v4DebugDirectoryName = "db_debug_v4"
    private static let projectsDataDirectoryName = "Projects"

    private let currentDataRootDirectory: URL
    private let store: ProjectsStore

    public init(currentDataRootDirectory: URL, store: ProjectsStore) {
        self.currentDataRootDirectory = currentDataRootDirectory
        self.store = store
    }

    /// 执行迁移。幂等、吞错。
    public func run() {
        let defaults = UserDefaults.standard

        // 幂等:.once 策略下,已迁移过则直接跳过
        if Self.policy == .once, defaults.bool(forKey: Self.migrationMarkerKey) {
            Self.logger.info("\(Self.t)项目迁移跳过(marker 已标记完成)")
            return
        }

        // 定位 v4 目录(当前 v5 dataRoot 的兄弟目录)
        guard let v4Root = resolveV4DataRootDirectory() else {
            defaults.set(true, forKey: Self.migrationMarkerKey)
            Self.logger.info("\(Self.t)项目迁移跳过(未找到 v4 数据目录,全新安装)")
            return
        }

        // 用 v4 路径构造一个只读用的临时 store,读 v4 的 projects.json
        let v4ProjectsDir = v4Root.appendingPathComponent(Self.projectsDataDirectoryName, isDirectory: true)
        let v4Store = ProjectsStore(pluginDirectory: v4ProjectsDir)
        let legacyProjects = v4Store.loadProjects()

        guard !legacyProjects.isEmpty else {
            defaults.set(true, forKey: Self.migrationMarkerKey)
            Self.logger.info("\(Self.t)项目迁移跳过(v4 项目列表为空)")
            return
        }

        // 合并:读 v5 当前列表,按 path 去重追加(v5 已有的优先)
        let currentProjects = store.loadProjects()
        let existingPaths = Set(currentProjects.map { $0.path })
        let newProjects = legacyProjects.filter { !existingPaths.contains($0.path) }

        guard !newProjects.isEmpty else {
            // v4 项目都已存在于 v5,无需写入
            defaults.set(true, forKey: Self.migrationMarkerKey)
            Self.logger.info("\(Self.t)项目迁移跳过(v4 项目均已存在于 v5)")
            return
        }

        let mergedProjects = currentProjects + newProjects

        // 确定 currentProject:优先用 v4 的 currentProject(若 v5 当前没有选中的话)
        let v5CurrentPath = store.loadCurrentProjectPath()
        let mergedCurrent: ProjectEntry?
        if let v5CurrentPath {
            // v5 已有 current,保持不变
            mergedCurrent = mergedProjects.first { $0.path == v5CurrentPath }
                ?? mergedProjects.first
        } else if let v4CurrentPath = v4Store.loadCurrentProjectPath() {
            // v5 无 current,采用 v4 的
            mergedCurrent = mergedProjects.first { $0.path == v4CurrentPath }
                ?? mergedProjects.first
        } else {
            mergedCurrent = mergedProjects.first
        }

        // 写入合并后的列表
        store.save(projects: mergedProjects, currentProject: mergedCurrent)
        defaults.set(true, forKey: Self.migrationMarkerKey)

        let policyLabel = Self.policy == .once ? "once" : "always"
        Self.logger.info("\(Self.t)项目迁移完成:读取 v4 \(legacyProjects.count) 个,新增 \(newProjects.count) 个,合并后共 \(mergedProjects.count) 个 [策略=\(policyLabel)]")
    }

    // MARK: - v4 目录定位

    /// 定位 v4 数据根目录(当前 v5 目录的兄弟)
    private func resolveV4DataRootDirectory() -> URL? {
        let parent = currentDataRootDirectory.deletingLastPathComponent()
        let fileManager = FileManager.default

        #if DEBUG
        let candidates = [Self.v4DirectoryName, Self.v4DebugDirectoryName]
        #else
        let candidates = [Self.v4DirectoryName]
        #endif

        for name in candidates {
            let dir = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: dir.path) {
                return dir
            }
        }
        return nil
    }
}
