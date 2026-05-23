import Testing
import Foundation
@testable import MemoryKit

@Suite("MemoryScope Tests")
struct MemoryScopeTests {

    @Test("MemoryScope 相等性")
    func memoryScopeEquality() {
        #expect(MemoryScope.global == MemoryScope.global)
        #expect(MemoryScope.project("/foo") == MemoryScope.project("/foo"))
        #expect(MemoryScope.project("/foo") != MemoryScope.project("/bar"))
        #expect(MemoryScope.global != MemoryScope.project("/foo"))
    }

    @Test("MemoryScope 项目路径包含特殊字符")
    func memoryScopeProjectPathWithSpecialChars() {
        let path1 = "/Users/angel/Code/My Project"
        let path2 = "/Users/angel/Code/My Project"
        let path3 = "/Users/angel/Code/Other Project"

        #expect(MemoryScope.project(path1) == MemoryScope.project(path2))
        #expect(MemoryScope.project(path1) != MemoryScope.project(path3))
    }
}
