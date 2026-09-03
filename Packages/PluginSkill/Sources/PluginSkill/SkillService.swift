import Foundation

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
/// 刻意只持有 `resourceURL`（`URL` 是 `Sendable`），不长期持有 `Bundle`，
/// 保证该提供者可安全跨 actor 使用。
public struct BuiltinSkillCatalog: BuiltinSkillProviding {
    public static let shared = BuiltinSkillCatalog()

    public let resourceURL: URL?
    public let directoryName: String
    public let maxSkillCount: Int

    public init(
        bundle: Bundle? = nil,
        directoryName: String = "BuiltinSkills",
        maxSkillCount: Int = 100
    ) {
        self.resourceURL = (bundle ?? .module).resourceURL
        self.directoryName = directoryName
        self.maxSkillCount = maxSkillCount
    }

    public func builtinSkills() -> [SkillMetadata] {
        guard let resourceURL,
              let directoryURL = resourceURL.appendingPathComponent(directoryName, isDirectory: true) as URL?,
              FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var skills: [SkillMetadata] = []
        for itemURL in contents {
            if skills.count >= maxSkillCount { break }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }

            let metadataURL = itemURL.appendingPathComponent("metadata.json")
            let skillMDURL = itemURL.appendingPathComponent("SKILL.md")
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  FileManager.default.fileExists(atPath: skillMDURL.path),
                  let data = try? Data(contentsOf: metadataURL),
                  let skill = try? JSONDecoder().decode(SkillMetadata.self, from: data),
                  !skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !skill.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            skills.append(SkillMetadata(
                id: skill.name,
                name: skill.name,
                title: skill.title,
                description: skill.description,
                triggers: skill.triggers,
                version: skill.version,
                contentPath: skillMDURL.path,
                modifiedAt: (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            ))
        }

        skills.sort { $0.name < $1.name }
        return skills
    }
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
public struct SkillScanner: SkillScanning {
    public let maxMetadataSize: Int
    public let maxSkillCount: Int

    public init(maxMetadataSize: Int = 1_048_576, maxSkillCount: Int = 100) {
        self.maxMetadataSize = maxMetadataSize
        self.maxSkillCount = maxSkillCount
    }

    public func scanSkills(projectPath: String) -> [SkillMetadata] {
        let directoryURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".agent/skills")

        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var skills: [SkillMetadata] = []
        for itemURL in contents {
            if skills.count >= maxSkillCount { break }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues?.isDirectory == true else { continue }

            let metadataURL = itemURL.appendingPathComponent("metadata.json")
            let skillMDURL = itemURL.appendingPathComponent("SKILL.md")
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  FileManager.default.fileExists(atPath: skillMDURL.path) else {
                continue
            }

            guard let metadataAttrs = try? FileManager.default.attributesOfItem(atPath: metadataURL.path),
                  let fileSize = metadataAttrs[.size] as? Int,
                  fileSize <= maxMetadataSize,
                  let data = try? Data(contentsOf: metadataURL),
                  let skill = try? JSONDecoder().decode(SkillMetadata.self, from: data),
                  !skill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !skill.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let modifiedAt = (try? skillMDURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            skills.append(SkillMetadata(
                id: skill.name,
                name: skill.name,
                title: skill.title,
                description: skill.description,
                triggers: skill.triggers,
                version: skill.version,
                contentPath: skillMDURL.path,
                modifiedAt: modifiedAt
            ))
        }

        skills.sort { $0.name < $1.name }
        return skills
    }
}

/// Skill 服务：带容量上限的内存缓存，避免高频对话中重复扫描文件系统。
///
/// 技能来源共两层：
/// 1. **内置技能**（`BuiltinSkillProviding`）：随 App 发布的通用技能，始终可用；
/// 2. **项目技能**（`SkillScanning`）：当前项目 `.agent/skills/` 下的技能。
///
/// 合并语义：同名时项目技能优先覆盖内置技能（用户可在项目里定制）。
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

    /// 当前项目可用技能 = 内置技能 + 项目技能。
    ///
    /// `projectPath` 为空时仅返回内置技能（无项目也能使用通用技能）。
    public func listSkills(projectPath: String) -> [SkillMetadata] {
        let builtin = listedBuiltinSkills()

        let projectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else { return builtin }

        if let cached = cachedSkills[projectPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.skills
        }
        let project = scanner.scanSkills(projectPath: projectPath)
        let skills = SkillMergePolicy.merge(builtin: builtin, project: project)
        evictIfNeeded()
        cachedSkills[projectPath] = (skills: skills, timestamp: Date())
        return skills
    }

    /// 仅返回内置技能（不合并项目技能）。
    public func listBuiltinSkills() -> [SkillMetadata] {
        listedBuiltinSkills()
    }

    public func invalidateCache(projectPath: String) {
        cachedSkills.removeValue(forKey: projectPath)
    }

    public func invalidateAllCache() {
        cachedSkills.removeAll()
    }

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
