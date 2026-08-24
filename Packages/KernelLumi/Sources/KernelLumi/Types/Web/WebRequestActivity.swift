import Foundation
@_exported import ProviderWebServer

// MARK: - Web Request Activity

/// 一次 Web 请求处理后的活动记录,用于 UI 反馈(toast)等。
///
/// 由 `LumiWebServer` 在请求处理完成后发射,经 `EventManager` 广播,供 UI 层
/// 订阅显示(如"主题已通过网络切换")。该类型为纯值类型且 `Sendable`,可安全
/// 从网络线程传递到主线程。
// MARK: - Notification UserInfo

/// `webRequestReceived` 事件的 userInfo 键命名空间。
public enum WebRequestActivityNotification {
    /// 携带 `WebRequestActivity` 的 userInfo 键。
    public static let activityKey = "WebRequestActivity"
}

public extension Notification {
    /// 取出 `.lumiWebRequestReceived` 通知携带的活动记录。
    var lumiWebRequestActivity: WebRequestActivity? {
        userInfo?[WebRequestActivityNotification.activityKey] as? WebRequestActivity
    }
}
