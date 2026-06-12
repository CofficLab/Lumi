import Foundation

public extension LumiPreviewFacade {
    /// 编辑器预览刷新判定策略。
    enum EditorPreviewRefreshPolicy {
        /// 判断收到一次源码/保存信号后，是否应该安排预览刷新。
        public static func shouldScheduleRefresh(
            previousPreviewID: String?,
            currentPreviewID: String?,
            hadRefreshableSessionBeforeUpdate: Bool,
            isRunningAfterUpdate: Bool,
            hasSessionAfterUpdate: Bool
        ) -> Bool {
            hadRefreshableSessionBeforeUpdate
                && isRunningAfterUpdate
                && hasSessionAfterUpdate
                && currentPreviewID == previousPreviewID
        }

        /// 判断等待中的刷新任务到期后，是否仍应该真正执行刷新。
        public static func shouldExecuteScheduledRefresh(
            activeFileKey: String?,
            expectedFileKey: String?,
            currentPreviewID: String?,
            expectedPreviewID: String?,
            isRunningOrShowingStalePreview: Bool,
            hasSession: Bool
        ) -> Bool {
            activeFileKey == expectedFileKey
                && currentPreviewID == expectedPreviewID
                && isRunningOrShowingStalePreview
                && hasSession
        }
    }
}
