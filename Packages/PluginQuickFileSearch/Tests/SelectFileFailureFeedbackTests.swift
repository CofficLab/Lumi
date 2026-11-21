import Testing
import Foundation
import ProviderEditor
@testable import QuickFileSearchPlugin

/// 回归 #187：打开失败必须显式报告并保留可重试状态。
///
/// 桥接 handler 返回 Bool；服务据此决定是否清空查询、是否设置
/// `openFailureMessage`。面板只在打开被接受后才收起。
/// 每个用例使用独立的 `FileSearchService` 实例，结束前还原桥接，
/// 避免全局 handler 泄漏到并行测试。
@MainActor
@Suite("选中文件失败反馈（回归 #187）", .serialized)
struct SelectFileFailureFeedbackTests {

    private func makeResult(path: String = "/tmp/project/App.swift") -> FileResult {
        FileResult(name: "App.swift", path: path, relativePath: "App.swift", isDirectory: false, score: 100)
    }

    @Test("handler 返回 false 时保留查询并报告失败")
    func failureKeepsQueryAndReports() async {
        let service = FileSearchService()
        service.searchQuery = "App"
        QuickFileSearchBridge.selectFileHandler = { _, _ in false }
        defer { QuickFileSearchBridge.selectFileHandler = nil }

        let opened = await service.selectFile(makeResult())

        #expect(!opened, "打开失败应返回 false")
        #expect(service.searchQuery == "App", "失败时查询必须保留，面板停留在可重试状态")
        #expect(service.openFailureMessage != nil, "失败必须显式报告")
    }

    @Test("handler 返回 true 时清空查询且无失败提示")
    func successClearsQuery() async {
        let service = FileSearchService()
        service.searchQuery = "App"
        service.openFailureMessage = "残留提示"
        QuickFileSearchBridge.selectFileHandler = { _, _ in true }
        defer { QuickFileSearchBridge.selectFileHandler = nil }

        let opened = await service.selectFile(makeResult())

        #expect(opened)
        #expect(service.searchQuery == "", "打开成功才清空查询")
        #expect(service.openFailureMessage == nil, "成功后失败提示应清除")
    }

    @Test("桥接未注入时按失败处理")
    func missingHandlerFails() async {
        let service = FileSearchService()
        service.searchQuery = "App"
        QuickFileSearchBridge.selectFileHandler = nil

        let opened = await service.selectFile(makeResult())

        #expect(!opened)
        #expect(service.searchQuery == "App", "无 handler 时不能清空查询")
        #expect(service.openFailureMessage != nil)
    }

    @Test("失败后再次成功选择会清除失败提示")
    func recoveryClearsFailureMessage() async {
        let service = FileSearchService()
        QuickFileSearchBridge.selectFileHandler = { _, _ in false }
        _ = await service.selectFile(makeResult())
        #expect(service.openFailureMessage != nil)

        QuickFileSearchBridge.selectFileHandler = { _, _ in true }
        defer { QuickFileSearchBridge.selectFileHandler = nil }
        let opened = await service.selectFile(makeResult())

        #expect(opened)
        #expect(service.openFailureMessage == nil, "重试成功应清除失败提示")
    }

    @Test("路径与窗口参数透传给桥接 handler")
    func forwardsPathAndWindow() async throws {
        let service = FileSearchService()
        let windowId = UUID()
        var captured: (path: String, windowId: UUID?)?
        QuickFileSearchBridge.selectFileHandler = { path, windowId in
            captured = (path, windowId)
            return true
        }
        defer { QuickFileSearchBridge.selectFileHandler = nil }

        let opened = await service.selectFile(makeResult(path: "/tmp/project/Src/Main.swift"), windowId: windowId)

        #expect(opened)
        let record = try #require(captured)
        #expect(record.path == "/tmp/project/Src/Main.swift")
        #expect(record.windowId == windowId)
    }
}
