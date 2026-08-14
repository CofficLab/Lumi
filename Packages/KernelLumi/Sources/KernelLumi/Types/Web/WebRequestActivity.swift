import Foundation

// MARK: - Web Request Activity

/// 一次 Web 请求处理后的活动记录,用于 UI 反馈(toast)等。
///
/// 由 `LumiWebServer` 在请求处理完成后发射,经 `EventManager` 广播,供 UI 层
/// 订阅显示(如"主题已通过网络切换")。该类型为纯值类型且 `Sendable`,可安全
/// 从网络线程传递到主线程。
public struct WebRequestActivity: Sendable {
    /// 归属插件 ID。
    public let pluginID: String
    /// HTTP 方法(如 "GET"、"POST")。
    public let method: String
    /// 路由路径(含 `:param` 占位符的模板)。
    public let path: String
    /// 路由的可选人类可读描述。
    public let description: String?
    /// 响应状态码。
    public let statusCode: Int
    /// 处理完成时间。
    public let timestamp: Date

    public init(
        pluginID: String,
        method: String,
        path: String,
        description: String?,
        statusCode: Int,
        timestamp: Date = Date()
    ) {
        self.pluginID = pluginID
        self.method = method
        self.path = path
        self.description = description
        self.statusCode = statusCode
        self.timestamp = timestamp
    }

    /// 是否为"写"操作(可能改变应用状态),toast 默认只提示这类请求。
    public var isMutation: Bool {
        switch method.uppercased() {
        case "POST", "PUT", "PATCH", "DELETE":
            return true
        default:
            return false
        }
    }

    /// 是否为成功响应(2xx)。
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}

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
