import Foundation
import Testing
@testable import KitResume

/// #430：已取消的简历导出必须立即以 CancellationError 中止，
/// 不得继续创建 WebKit 会话、逐页捕获 PDF 或写盘。
@Suite("ResumeHTMLExporter 取消传播")
@MainActor
struct ResumeExportCancellationTests {
    @Test("已取消的任务在渲染开始前立即中止")
    func cancelledExportAbortsBeforeRendering() async {
        let task = Task {
            try await ResumeHTMLExporter.exportPDF(
                html: "<html><body>never rendered</body></html>",
                fileURL: nil,
                paper: .a4
            )
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
