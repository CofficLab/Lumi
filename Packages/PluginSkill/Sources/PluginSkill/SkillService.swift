import Foundation
import ProviderSkill

/// Skill 扫描器协议（可注入 mock 测试）。
public protocol SkillScanning: Sendable {
    func scanSkills(projectPath: String) -> [SkillMetadata]
}

/// 内置技能提供者协议：返回应用随包携带的技能元数据。
///
/// 用于支持「无需任何项目即可使用的基础技能」（如 swiftui-standards）。
public protocol BuiltinSkillProviding: Sendable {
    func builtinSkills() -> [SkillMetadata]
}

/// 默认内置技能目录。
///
/// 从 `Bundle.module` 加载随包携带的 `BuiltinSkills/` 目录，每个子目录
/// 一个技能（与项目技能格式一致：`metadata.json` + `SKILL.md`）。
///
/// 解析复用 `SkillDirectoryLoader`（与项目扫描 / 第三方插件共用同一套
/// 目录约定）。刻意只持有 `resourceURL`（`URL` 是 `Sendable`），不长期
/// 持有 `Bundle`，保证该提供者可安全跨 actor 使用。
public struct BuiltinSkillCatalog: BuiltinSkillProviding {
    public static let shared = BuiltinSkillCatalog()

    public let resourceURL: URL?
    public let directoryName: String
    public let loader: SkillDirectoryLoader

    /// 以「Bundle 资源根 + 目录名」构造。
    public init(
        bundle: Bundle? = nil,
        directoryName: String = "BuiltinSkills",
        maxSkillCount: Int = 100
    ) {
        self.resourceURL = (bundle ?? .module).resourceURL
        self.directoryName = directoryName
        self.loader = SkillDirectoryLoader(maxSkillCount: maxSkillCount)
    }

    /// 直接以技能根目录构造（第三方插件可复用，指向自己的资源目录）。
    public init(resourceURL: URL?, directoryName: String = "BuiltinSkills", maxSkillCount: Int = 100) {
        self.resourceURL = resourceURL
        self.directoryName = directoryName
        self.loader = SkillDirectoryLoader(maxSkillCount: maxSkillCount)
    }

    public func builtinSkills() -> [SkillMetadata] {
        guard let resourceURL else { return [] }
        let directoryURL = resourceURL.appendingPathComponent(directoryName, isDirectory: true)
        return loader.loadSkills(from: directoryURL)
    }
}

/// 把一组静态技能包装成 `SkillContributing`（插件贡献通道）。
///
/// `PluginSkill` 用此把「内置目录」作为 contributor 注入 `SkillProviding`，
/// 与其它插件贡献技能走同一条通道。
public struct StaticSkillContributor: SkillContributing {
    public let providerID: String
    public let skills: [SkillMetadata]

    public init(providerID: String, skills: [SkillMetadata]) {
        self.providerID = providerID
        self.skills = skills
    }

    public var allSkills: [SkillMetadata] { skills }
}

/// 合并来源：内置技能 + 项目技能，同名时项目技能优先（去重），按名称排序。
public enum SkillMergePolicy {
    public static func merge(
        builtin: [SkillMetadata],
        project: [SkillMetadata]
    ) -> [SkillMetadata] {
        let projectNames = Set(project.map(\.name))
        return (project + builtin.filter { !projectNames.contains($0.name) })
            .sorted { $0.name < $1.name }
    }
}

/// 默认文件系统扫描器：扫描 `.agent/skills/` 目录，解析 metadata.json，
/// 验证 SKILL.md 存在。复刻旧版 `SkillScanner`。
///
/// 内部复用 `SkillDirectoryLoader`（与内置 / 插件贡献共用同一套目录约定）。
public struct SkillScanner: SkillScanning {
    public let loader: SkillDirectoryLoader

    public init(maxMetadataSize: Int = 1_048_576, maxSkillCount: Int = 100) {
        self.loader = SkillDirectoryLoader(maxMetadataSize: maxMetadataSize, maxSkillCount: maxSkillCount)
    }

    /// 直接以 loader 构造（便于测试注入自定义 loader）。
    public init(loader: SkillDirectoryLoader) {
        self.loader = loader
    }

    public func scanSkills(projectPath: String) -> [SkillMetadata] {
        let directoryURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".agent/skills")
        return loader.loadSkills(from: directoryURL)
    }
}

/// Skill 服务：项目层扫描 + 三层合并 + 缓存。
///
/// 技能来源共三层：
/// 1. **插件贡献**（`SkillProviding`）：任何插件通过 Provider 注入的技能；
/// 2. **项目技能**（`SkillScanning`）：当前项目 `.agent/skills/` 下的技能；
/// 3. **内置技能**（`BuiltinSkillProviding`）：随 App 发布的通用技能。
///
/// `SkillService` 自身不持有 `SkillProviding`（其 `@MainActor` 隔离与 actor
/// 冲突），而是由 `SkillPlugin`（`@MainActor`）在钩子中先读取 Provider 的
/// 「插件贡献 + 内置」层，作为参数传入 `mergedSkills`，再叠加项目层。
///
/// 合并语义：项目技能优先覆盖插件贡献，插件贡献再覆盖内置（同名去重）。
public actor SkillService {
    public static let shared = SkillService()

    private var cachedSkills: [String: (skills: [SkillMetadata], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval
    private let maxCacheEntries: Int
    private let scanner: any SkillScanning
    private let builtinProvider: any BuiltinSkillProviding

    /// 内置技能是否已作为独立缓存键缓存。
    private var builtinCacheKey: String { "_builtin" }

    public init(
        cacheTTL: TimeInterval = 30,
        maxCacheEntries: Int = 50,
        scanner: any SkillScanning = SkillScanner(),
        builtinProvider: any BuiltinSkillProviding = BuiltinSkillCatalog.shared
    ) {
        self.cacheTTL = cacheTTL
        self.maxCacheEntries = maxCacheEntries
        self.scanner = scanner
        self.builtinProvider = builtinProvider
    }

    /// 当前项目可用技能 = 项目技能 + 传入的底座（插件贡献 + 内置）。
    ///
    /// `projectPath` 为空时仅返回 `baseSkills`（无项目也能用通用技能）。
    /// `baseSkills` 由调用方（`SkillPlugin`）从 `SkillProviding` 读取。
    public func listSkills(
        projectPath: String,
        baseSkills: [SkillMetadata] = []
    ) -> [SkillMetadata] {
        let projectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else { return baseSkills }

        if let cached = cachedSkills[projectPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.skills
        }
        let project = scanner.scanSkills(projectPath: projectPath)
        let skills = SkillMergePolicy.merge(builtin: baseSkills, project: project)
        evictIfNeeded()
        cachedSkills[projectPath] = (skills: skills, timestamp: Date())
        return skills
    }

    /// 仅返回内置技能（随包目录）。
    public func listBuiltinSkills() async -> [SkillMetadata] {
        listedBuiltinSkills()
    }

    public func invalidateCache(projectPath: String) {
        cachedSkills.removeValue(forKey: projectPath)
    }

    public func invalidateAllCache() {
        cachedSkills.removeAll()
    }

    // MARK: - 内部

    private func listedBuiltinSkills() -> [SkillMetadata] {
        if let cached = cachedSkills[builtinCacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.skills
        }
        let skills = builtinProvider.builtinSkills()
        cachedSkills[builtinCacheKey] = (skills: skills, timestamp: Date())
        return skills
    }

    private func evictIfNeeded() {
        guard cachedSkills.count >= maxCacheEntries else { return }
        let sorted = cachedSkills.sorted { $0.value.timestamp < $1.value.timestamp }
        let removeCount = maxCacheEntries / 2
        for i in 0..<removeCount {
            cachedSkills.removeValue(forKey: sorted[i].key)
        }
    }
}