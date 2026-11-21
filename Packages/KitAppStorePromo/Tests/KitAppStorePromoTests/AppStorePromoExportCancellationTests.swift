import Foundation
import Testing
@testable import KitAppStorePromo

/// #430：已取消的促销图导出必须立即以 CancellationError 中止，
/// 不得继续创建 WebKit 会话、渲染或写盘。
@Suite("AppStorePromoHTMLExporter 取消传播")
@MainActor
struct AppStorePromoExportCancellationTests {
    @Test("已取消的任务在渲染开始前立即中止")
    func cancelledExportAbortsBeforeRendering() async throws {
        let preset = try #require(AppStorePromoDisplaySpec.presets.first)
        let task = Task {
            try await AppStorePromoHTMLExporter.exportPNG(
                html: "<html><body>never rendered</body></html>",
                fileURL: nil,
                readAccessRootURL: nil,
                preset: preset
            )
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
