import Foundation
import Testing
@testable import KitPrototype

/// #430：已取消的原型导出必须立即以 CancellationError 中止，
/// 不得继续创建 WebKit 会话、渲染或写盘。
@Suite("PrototypeHTMLExporter 取消传播")
@MainActor
struct PrototypeExportCancellationTests {
    @Test("已取消的任务在渲染开始前立即中止")
    func cancelledExportAbortsBeforeRendering() async throws {
        let device = try #require(PrototypeDeviceKind.iPhone15Pro.preset)
        let task = Task {
            try await PrototypeHTMLExporter.exportPNG(
                html: "<html><body>never rendered</body></html>",
                fileURL: nil,
                device: device
            )
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
