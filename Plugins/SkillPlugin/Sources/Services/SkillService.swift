import Foundation
import SuperLogKit

/// Skill 服务
///
/// 负责扫描 `.agent/skills/` 目录，解析 `metadata.json` 和验证 `SKILL.md`。
/// 使用带容量上限的内存缓存，避免高频对话中重复扫描文件系统。
public actor SkillService: SuperLog {
    public nonisolated static let emoji = "💾"
    
    // MARK: - 单例

    public static let shared = SkillService()

    // MARK: - 属性

    /// 内存缓存：projectPath → (skills, timestamp)
    private var cachedSkills: [String: (skills: [SkillMetadata], timestamp: Date)] = [:]

    /// 缓存有效期（秒）
    private let cacheTTL: TimeInterval

    /// 最大缓存条目数（防止多项目场景下内存无限增长）
    private let maxCacheEntries: Int

    /// 文件系统操作器（可替换用于测试）
    private let scanner: SkillScanning

    // MARK: - 初始化

    public init(
        cacheTTL: TimeInterval = 30,
        maxCacheEntries: Int = 50,
        scanner: SkillScanning = SkillScanner()
    ) {
        self.cacheTTL = cacheTTL
        self.maxCacheEntries = maxCacheEntries
        self.scanner = scanner
    }

    // MARK: - 公开方法

    /// 获取指定项目的可用 Skill 列表
    ///
    /// 优先使用缓存，缓存过期或不存在时重新扫描文件系统。
    /// 目录不存在或为空时返回空数组，不抛出错误。
    public func listSkills(projectPath: String) -> [SkillMetadata] {
        // 检查缓存
        if let cached = cachedSkills[projectPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            if SkillPlugin.verbose {
                SkillPlugin.logger.info("\(Self.t)使用缓存数据，找到 \(cached.skills.count) 个 Skill")
            }
            return cached.skills
        }

        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)缓存未命中或已过期，重新扫描文件系统")
        }
        
        // 扫描文件系统
        let skills = scanner.scanSkills(projectPath: projectPath)

        // 更新缓存（超限时淘汰最早的条目）
        evictIfNeeded()
        cachedSkills[projectPath] = (skills: skills, timestamp: Date())

        return skills
    }

    /// 清除指定项目的缓存
    public func invalidateCache(projectPath: String) {
        cachedSkills.removeValue(forKey: projectPath)
        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)已清除项目缓存：\(projectPath)")
        }
    }

    /// 清除所有缓存
    public func invalidateAllCache() {
        cachedSkills.removeAll()
        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)已清除所有缓存")
        }
    }

    // MARK: - 私有方法

    /// 当缓存条目超过上限时，淘汰最早的一半
    private func evictIfNeeded() {
        guard cachedSkills.count >= maxCacheEntries else { return }

        let sorted = cachedSkills.sorted { $0.value.timestamp < $1.value.timestamp }
        let removeCount = maxCacheEntries / 2
        for i in 0..<removeCount {
            cachedSkills.removeValue(forKey: sorted[i].key)
        }
        
        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)缓存已满，已淘汰 \(removeCount) 个旧条目")
        }
    }
}
