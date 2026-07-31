import Foundation
import Testing
@testable import LumiKernel

/// `ProjectProviding` 的内核契约测试。
///
/// 模块对应:`Sources/LumiKernel/Providers/ProjectProviding.swift`。
/// 验证注册/解析 + current/open 文件去重语义。
@Suite("ProjectProviding")
@MainActor
struct ProjectProvidingTests {
    @Test("更新当前文件时去重并标准化路径,且经 kernel 透传可见")
    func updateCurrentFileDedupesAndExposesThroughKernel() throws {
        let kernel = KernelTestKit.makeKernel()
        let project = MockProjectProviding()
        try kernel.registerProject(project)

        let fileURL = URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift")
        kernel.project?.updateCurrentFile(fileURL)

        let standardized = fileURL.standardizedFileURL
        #expect(project.openFileURLs == [standardized])
        #expect(project.currentFileURL == standardized)
        #expect(kernel.project?.currentFileURL == standardized)
        #expect(kernel.project?.openFileURLs == [standardized])
    }
}
