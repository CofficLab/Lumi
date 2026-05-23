import Testing
import Foundation
@testable import MemoryKit

@Suite("MemoryItem Tests")
struct MemoryItemTests {

    @Test("MemoryItem 时效计算")
    func memoryItemAgeCalculation() {
        let now = Date()
        let fresh = MemoryItem(
            id: "fresh", filename: "fresh.md", type: .user,
            name: "Fresh", description: "Fresh memory",
            content: "Content", createdAt: now, updatedAt: now,
            filePath: "/tmp/fresh.md"
        )
        #expect(fresh.ageInDays == 0)
        #expect(!fresh.isStale(thresholdDays: 7))

        let old = MemoryItem(
            id: "old", filename: "old.md", type: .user,
            name: "Old", description: "Old memory",
            content: "Content",
            createdAt: now, updatedAt: now.addingTimeInterval(-8 * 86400),
            filePath: "/tmp/old.md"
        )
        #expect(old.ageInDays == 8)
        #expect(old.isStale(thresholdDays: 7))
        #expect(!old.isStale(thresholdDays: 10))
    }

    @Test("MemoryItem 格式化摘要")
    func memoryItemFormattedSummary() {
        let item = MemoryItem(
            id: "test", filename: "test.md", type: .feedback,
            name: "No Summary", description: "Don't summarize",
            content: "Content", createdAt: Date(), updatedAt: Date(),
            filePath: "/tmp/test.md"
        )
        #expect(item.formattedSummary() == "[feedback] No Summary — Don't summarize")
    }

    @Test("MemoryItem 格式化内容含时效提醒")
    func memoryItemFormattedContentWithStaleWarning() {
        let now = Date()
        let stale = MemoryItem(
            id: "stale", filename: "stale.md", type: .project,
            name: "Old Decision", description: "Made long ago",
            content: "Use database X",
            createdAt: now, updatedAt: now.addingTimeInterval(-30 * 86400),
            filePath: "/tmp/stale.md"
        )
        let content = stale.formattedContent(staleThresholdDays: 7)
        #expect(content.contains("⚠️"))
        #expect(content.contains("30 天前"))

        // 新鲜记忆不应含提醒
        let fresh = MemoryItem(
            id: "fresh", filename: "fresh.md", type: .user,
            name: "Fresh", description: "New",
            content: "Content", createdAt: now, updatedAt: now,
            filePath: "/tmp/fresh.md"
        )
        let freshContent = fresh.formattedContent(staleThresholdDays: 7)
        #expect(!freshContent.contains("⚠️"))
    }

    @Test("MemoryItem Codable")
    func memoryItemCodable() async throws {
        let now = Date()
        let item = MemoryItem(
            id: "test", filename: "test.md", type: .feedback,
            name: "Test", description: "A test",
            content: "Content body", createdAt: now, updatedAt: now,
            filePath: "/tmp/test.md"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(item)
        let decoded = try decoder.decode(MemoryItem.self, from: data)

        #expect(decoded.id == item.id)
        #expect(decoded.type == item.type)
        #expect(decoded.name == item.name)
        #expect(decoded.content == item.content)
    }
}
