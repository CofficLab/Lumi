import Testing
@testable import LumiPreviewKit

@Suite("EditorPreviewRefreshPolicy")
struct EditorPreviewRefreshPolicyTests {

    @Test("保存或文本变化后，原 preview 仍选中且 session 仍在运行时安排刷新")
    func scheduleRefreshWhenPreviewStillMatches() {
        #expect(
            EditorPreviewRefreshPolicy.shouldScheduleRefresh(
                previousPreviewID: "preview-1",
                currentPreviewID: "preview-1",
                hadRefreshableSessionBeforeUpdate: true,
                isRunningAfterUpdate: true,
                hasSessionAfterUpdate: true
            )
        )
    }

    @Test("切换到其他 preview 后不安排旧刷新")
    func doesNotScheduleRefreshWhenPreviewChanges() {
        #expect(
            !EditorPreviewRefreshPolicy.shouldScheduleRefresh(
                previousPreviewID: "preview-1",
                currentPreviewID: "preview-2",
                hadRefreshableSessionBeforeUpdate: true,
                isRunningAfterUpdate: true,
                hasSessionAfterUpdate: true
            )
        )
    }

    @Test("没有可刷新的旧 session 时不安排刷新")
    func doesNotScheduleRefreshWithoutRefreshableSession() {
        #expect(
            !EditorPreviewRefreshPolicy.shouldScheduleRefresh(
                previousPreviewID: "preview-1",
                currentPreviewID: "preview-1",
                hadRefreshableSessionBeforeUpdate: false,
                isRunningAfterUpdate: true,
                hasSessionAfterUpdate: true
            )
        )
    }

    @Test("延迟刷新到期时仍满足上下文条件才真正执行")
    func executeScheduledRefreshRequiresStableContext() {
        #expect(
            EditorPreviewRefreshPolicy.shouldExecuteScheduledRefresh(
                activeFileKey: "file-a",
                expectedFileKey: "file-a",
                currentPreviewID: "preview-1",
                expectedPreviewID: "preview-1",
                isRunningOrShowingStalePreview: true,
                hasSession: true
            )
        )
    }

    @Test("文件或 preview 已切换时取消延迟刷新")
    func executeScheduledRefreshCancelsOnFileOrPreviewSwitch() {
        #expect(
            !EditorPreviewRefreshPolicy.shouldExecuteScheduledRefresh(
                activeFileKey: "file-b",
                expectedFileKey: "file-a",
                currentPreviewID: "preview-2",
                expectedPreviewID: "preview-1",
                isRunningOrShowingStalePreview: true,
                hasSession: true
            )
        )
    }
}
