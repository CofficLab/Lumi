import Foundation

extension Notification.Name {
    /// 用户触发截图的通知
    ///
    /// 由命令(⌘⇧S)或 ActionBar 按钮 post。`ChatScreenshotPlugin.onReady`
    /// 订阅此通知并启动截图流程。
    public static let lumiCaptureScreenshot = Notification.Name("lumi.captureScreenshot")
}