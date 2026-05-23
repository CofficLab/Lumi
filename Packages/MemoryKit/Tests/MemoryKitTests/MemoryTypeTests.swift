import Testing
import Foundation
@testable import MemoryKit

@Suite("MemoryType Tests")
struct MemoryTypeTests {

    @Test("MemoryType 有四种类型")
    func memoryTypeHasFourTypes() {
        #expect(MemoryType.allCases.count == 4)
        #expect(MemoryType(rawValue: "user") == .user)
        #expect(MemoryType(rawValue: "feedback") == .feedback)
        #expect(MemoryType(rawValue: "project") == .project)
        #expect(MemoryType(rawValue: "reference") == .reference)
        #expect(MemoryType(rawValue: "invalid") == nil)
    }

    @Test("MemoryType 默认作用域")
    func memoryTypeDefaultScope() {
        #expect(MemoryType.user.defaultScope == .global)
        #expect(MemoryType.feedback.defaultScope == .global)
    }

    @Test("MemoryType 显示名称")
    func memoryTypeDisplayNames() {
        #expect(MemoryType.user.displayName == "User")
        #expect(MemoryType.user.displayNameZh == "用户")
        #expect(MemoryType.feedback.displayName == "Feedback")
        #expect(MemoryType.project.displayNameZh == "项目")
        #expect(MemoryType.reference.displayName == "Reference")
    }

    @Test("MemoryType Codable")
    func memoryTypeCodable() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in MemoryType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(MemoryType.self, from: data)
            #expect(decoded == type)
        }
    }
}
