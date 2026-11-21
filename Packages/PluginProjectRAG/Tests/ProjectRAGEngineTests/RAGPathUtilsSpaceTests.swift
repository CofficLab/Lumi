import Foundation
import Testing
@testable import ProjectRAGEngine

/// 回归 #605：normalizeProjectPath 过去对入参做空白 trim，而 macOS 目录名
/// 可以合法地以空格开头/结尾，trim 会把显式路径改写成另一个真实存在的
/// 目录。修复后只处理空串与多余斜杠，保留合法空格。
@Suite("RAGPathUtils 空格路径", .serialized)
struct RAGPathUtilsSpaceTests {

    @Test("保留路径结尾的合法空格")
    func trailingSpaceIsPreserved() {
        let spaced = FileManager.default.temporaryDirectory.path + "/lumi-605 "
        let normalized = RAGPathUtils.normalizeProjectPath(spaced)
        let expected = URL(fileURLWithPath: spaced).standardizedFileURL.path
        #expect(normalized == expected)
        #expect(normalized.hasSuffix(" "))
    }

    @Test("保留路径开头的合法空格")
    func leadingSpaceIsPreserved() {
        let spaced = FileManager.default.temporaryDirectory.path + "/ lumi-605"
        let normalized = RAGPathUtils.normalizeProjectPath(spaced)
        let expected = URL(fileURLWithPath: spaced).standardizedFileURL.path
        #expect(normalized == expected)
    }

    @Test("空串仍返回空串")
    func emptyStringStaysEmpty() {
        #expect(RAGPathUtils.normalizeProjectPath("") == "")
    }

    @Test("普通路径行为不变：标准化的绝对路径且不带结尾斜杠")
    func plainPathUnchanged() {
        let plain = FileManager.default.temporaryDirectory.path + "/lumi-plain"
        #expect(RAGPathUtils.normalizeProjectPath(plain) == URL(fileURLWithPath: plain).standardizedFileURL.path)
        #expect(RAGPathUtils.normalizeProjectPath(plain + "/") == URL(fileURLWithPath: plain).standardizedFileURL.path)
    }
}
