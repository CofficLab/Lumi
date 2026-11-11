import CoreGraphics
import Foundation
import KitAgentTool
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #866：`resolution_height = 1` 曾被接受，最终产生高度为 0 的录制配置。
///
/// H.264 要求宽高为偶数，采集侧用 `height & ~1` 做对齐，于是高度 1 变成 0。
/// 0 高度既无法被 ScreenCaptureKit 接受，也无法建立 AVAssetWriter 输入，
/// 错误只会笼统地表现为编码失败。
@Suite("录制分辨率校验")
struct RecordingResolutionTests {

    @Test("高度 1 在启动前被拒绝")
    func heightOneIsRejected() {
        #expect(throws: RecordingError.self) {
            try RecordingResolution.validate(height: 1)
        }
    }

    @Test("高度 0 与负数同样被拒绝")
    func nonPositiveHeightsAreRejected() {
        #expect(throws: RecordingError.self) {
            try RecordingResolution.validate(height: 0)
        }
        #expect(throws: RecordingError.self) {
            try RecordingResolution.validate(height: -10)
        }
    }

    @Test("高度 2 及以上与「跟随源尺寸」都被放行")
    func validHeightsPass() throws {
        try RecordingResolution.validate(height: 2)
        try RecordingResolution.validate(height: 1080)
        try RecordingResolution.validate(height: nil)
    }

    @Test("拒绝时给出具体的参数错误")
    func rejectionCarriesTheRequestedHeight() {
        do {
            try RecordingResolution.validate(height: 1)
            Issue.record("Expected the validation to reject a height of 1")
        } catch let error as RecordingError {
            guard case .invalidResolutionHeight(let height) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(height == 1)
            #expect((error.errorDescription ?? "").contains("1"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("输出尺寸对齐后不会为 0")
    func outputSizeIsNeverZero() {
        let size = ScreenCaptureRecorder.computeOutputSize(
            contentSize: CGSize(width: 1920, height: 1080),
            resolutionHeight: 1
        )

        #expect(size.height >= 2)
        #expect(size.width >= 2)
    }

    @Test("合法的分辨率仍然按偶数对齐")
    func validResolutionStaysEven() {
        let size = ScreenCaptureRecorder.computeOutputSize(
            contentSize: CGSize(width: 1920, height: 1080),
            resolutionHeight: 1081
        )

        #expect(size.height == 1080)
        #expect(size.width % 2 == 0)
    }

    @Test("工具在参数层就拒绝高度 1")
    func toolRejectsHeightOne() async {
        let tool = StartRecordingV2Tool()

        do {
            _ = try await tool.execute(arguments: [
                "target": ToolArgument("display"),
                "resolution_height": ToolArgument(1),
            ])
            Issue.record("Expected the tool to reject a resolution height of 1")
        } catch {
            #expect(error.localizedDescription.contains("2"))
        }
    }

    @MainActor
    @Test("start 在权限检查前就拒绝非法高度")
    func startRejectsInvalidHeightBeforePermissions() async {
        let manager = RecordingSessionManager()
        let config = RecordingConfig(
            target: .display(),
            resolutionHeight: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        do {
            try await manager.start(config: config)
            Issue.record("Expected start to reject a resolution height of 1")
        } catch let error as RecordingError {
            guard case .invalidResolutionHeight = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(manager.hasActiveSession == false)
    }
}
