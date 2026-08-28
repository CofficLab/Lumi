import Foundation

/// Skill 扫描器协议（可注入 mock 测试）。
public protocol SkillScanning: Sendable {
    func scanSkills(projectPath: String) -> [SkillMetadata]
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
public actor SkillService {
    public static let shared = SkillService()

    private var cachedSkills: [String: (skills: [SkillMetadata], timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval
    private let maxCacheEntries: Int
    private let scanner: any SkillScanning

    public init(
        cacheTTL: TimeInterval = 30,
        maxCacheEntries: Int = 50,
        scanner: any SkillScanning = SkillScanner()
    ) {
        self.cacheTTL = cacheTTL
        self.maxCacheEntries = maxCacheEntries
        self.scanner = scanner
    }

    public func listSkills(projectPath: String) -> [SkillMetadata] {
        if let cached = cachedSkills[projectPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.skills
        }
        let skills = scanner.scanSkills(projectPath: projectPath)
        evictIfNeeded()
        cachedSkills[projectPath] = (skills: skills, timestamp: Date())
        return skills
    }

    public func invalidateCache(projectPath: String) {
        cachedSkills.removeValue(forKey: projectPath)
    }

    public func invalidateAllCache() {
        cachedSkills.removeAll()
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
