import Foundation
import Testing
@testable import SkillKit

// MARK: - Mock Scanner (Shared)

/// 可控制返回结果的 Mock 扫描器
final class ControllableMockScanner: SkillScanning, @unchecked Sendable {
    var result: [SkillMetadata] = []
    var callCount = 0
    var lastProjectPath: String?

    func scanSkills(projectPath: String) -> [SkillMetadata] {
        callCount += 1
        lastProjectPath = projectPath
        return result
    }
}

// MARK: - SkillService Tests

struct SkillServiceTests {

    // MARK: - Basic Behavior

    @Test
    func listSkillsReturnsSkillsFromScanner() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "a", title: "A", description: "Skill A"),
            SkillMetadata(name: "b", title: "B", description: "Skill B")
        ]

        let service = SkillService(scanner: mockScanner)
        let skills = await service.listSkills(projectPath: "/test/project")

        #expect(skills.count == 2)
        #expect(skills[0].name == "a")
        #expect(skills[1].name == "b")
    }

    @Test
    func listSkillsReturnsEmptyForEmptyDirectory() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = []

        let service = SkillService(scanner: mockScanner)
        let skills = await service.listSkills(projectPath: "/empty/project")

        #expect(skills.isEmpty)
    }

    @Test
    func listSkillsPassesProjectPathToScanner() async {
        let mockScanner = ControllableMockScanner()

        let service = SkillService(scanner: mockScanner)
        _ = await service.listSkills(projectPath: "/my/project")

        #expect(mockScanner.lastProjectPath == "/my/project")
    }

    @Test
    func listSkillsHandlesEmptyProjectPath() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = []

        let service = SkillService(scanner: mockScanner)
        let skills = await service.listSkills(projectPath: "")

        #expect(skills.isEmpty)
        #expect(mockScanner.callCount == 1)
    }

    // MARK: - Caching

    @Test
    func listSkillsCachesWithinTTL() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "cached", title: "Cached", description: "Should be cached")
        ]

        let service = SkillService(cacheTTL: 10, scanner: mockScanner)

        let first = await service.listSkills(projectPath: "/proj")
        let second = await service.listSkills(projectPath: "/proj")

        #expect(mockScanner.callCount == 1)
        #expect(first.count == second.count)
        #expect(first[0].name == "cached")
    }

    @Test
    func listSkillsDifferentProjectsHaveIndependentCache() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "s", title: "S", description: "Skill")
        ]

        let service = SkillService(cacheTTL: 10, scanner: mockScanner)

        _ = await service.listSkills(projectPath: "/project-a")
        _ = await service.listSkills(projectPath: "/project-b")

        #expect(mockScanner.callCount == 2)
    }

    @Test
    func invalidateCacheForcesRescan() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "s", title: "S", description: "Skill")
        ]

        let service = SkillService(cacheTTL: 3600, scanner: mockScanner)

        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 1)

        await service.invalidateCache(projectPath: "/proj")

        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 2)
    }

    @Test
    func invalidateAllCacheClearsAllProjects() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "s", title: "S", description: "Skill")
        ]

        let service = SkillService(cacheTTL: 3600, scanner: mockScanner)

        _ = await service.listSkills(projectPath: "/proj-a")
        _ = await service.listSkills(projectPath: "/proj-b")
        #expect(mockScanner.callCount == 2)

        await service.invalidateAllCache()

        _ = await service.listSkills(projectPath: "/proj-a")
        _ = await service.listSkills(projectPath: "/proj-b")
        #expect(mockScanner.callCount == 4)
    }

    @Test
    func invalidateNonexistentProjectIsNoop() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [SkillMetadata(name: "s", title: "S", description: "Skill")]

        let service = SkillService(cacheTTL: 3600, scanner: mockScanner)
        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 1)

        // Invalidate a different project — should not affect existing cache
        await service.invalidateCache(projectPath: "/other-proj")

        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 1) // Still cached
    }

    // MARK: - Cache TTL Expiry

    @Test
    func listSkillsRescansAfterTTLExpires() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "s", title: "S", description: "Skill")
        ]

        let service = SkillService(cacheTTL: 0.1, scanner: mockScanner)

        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 1)

        // Wait for TTL to expire
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        _ = await service.listSkills(projectPath: "/proj")
        #expect(mockScanner.callCount == 2)
    }

    // MARK: - Cache Eviction

    @Test
    func cacheEvictsOldestWhenExceedsMaxEntries() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [SkillMetadata(name: "s", title: "S", description: "Skill")]

        // Max 3 entries
        let service = SkillService(cacheTTL: 3600, maxCacheEntries: 3, scanner: mockScanner)

        // Fill cache with 3 projects
        _ = await service.listSkills(projectPath: "/proj-1")
        _ = await service.listSkills(projectPath: "/proj-2")
        _ = await service.listSkills(projectPath: "/proj-3")
        #expect(mockScanner.callCount == 3)

        // Add a 4th — should trigger eviction of oldest half
        _ = await service.listSkills(projectPath: "/proj-4")
        #expect(mockScanner.callCount == 4)

        // proj-1 should have been evicted (oldest), so accessing it again triggers a new scan
        _ = await service.listSkills(projectPath: "/proj-1")
        #expect(mockScanner.callCount == 5) // Rescanned
    }

    // MARK: - Concurrent Access

    @Test
    func concurrentAccessDoesNotCrash() async {
        let mockScanner = ControllableMockScanner()
        mockScanner.result = [
            SkillMetadata(name: "s", title: "S", description: "Skill")
        ]

        let service = SkillService(cacheTTL: 10, scanner: mockScanner)

        await withTaskGroup(of: [SkillMetadata].self) { group in
            for i in 0..<20 {
                group.addTask {
                    await service.listSkills(projectPath: "/proj-\(i % 3)")
                }
            }

            var count = 0
            for await result in group {
                count += result.count
            }
            #expect(count > 0)
        }
    }
}
