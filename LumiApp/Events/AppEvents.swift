import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    /// 应用启动完成的通知
    static let applicationDidFinishLaunching = Notification.Name("applicationDidFinishLaunching")

    /// 应用即将终止的通知
    static let applicationWillTerminate = Notification.Name("applicationWillTerminate")

    /// 应用变为活跃状态的通知
    static let applicationDidBecomeActive = Notification.Name("applicationDidBecomeActive")

    /// 应用变为非活跃状态的通知
    static let applicationDidResignActive = Notification.Name("applicationDidResignActive")

    /// 请求更新菜单栏外观的通知
    /// userInfo: ["isActive": Bool, "source": String]
    static let requestMenuBarAppearanceUpdate = Notification.Name("requestMenuBarAppearanceUpdate")

    /// 请求更新状态栏网速显示的通知
    /// userInfo: ["uploadSpeed": Double, "downloadSpeed": Double, "source": String]
    static let requestStatusBarSpeedUpdate = Notification.Name("requestStatusBarSpeedUpdate")

    /// 检查应用更新的通知
    static let checkForUpdates = Notification.Name("checkForUpdates")

    /// 应用更新已在后台下载完成，可安装
    /// userInfo: ["version": String]
    static let appUpdateReadyToInstall = Notification.Name("appUpdateReadyToInstall")

    /// 安装已下载完成的应用更新
    static let installPreparedAppUpdate = Notification.Name("installPreparedAppUpdate")

    /// 文件拖放到聊天框的通知
    /// userInfo: ["fileURL": URL]
    static let fileDroppedToChat = Notification.Name("fileDroppedToChat")

    /// 请求使用指定路由打开新窗口
    /// userInfo: ["route": LumiWindowRoute]
    static let openWindowWithRoute = Notification.Name("openWindowWithRoute")

    /// 请求在当前活跃窗口的编辑器中打开文件
    /// userInfo: ["url": URL, "windowId": UUID?]
    static let openFileInEditor = Notification.Name("openFileInEditor")

    /// 请求将当前窗口状态写入磁盘（如项目切换后）
    static let windowStateShouldPersist = Notification.Name("windowStateShouldPersist")

    /// 窗口关闭通知（窗口状态持久化等用于刷盘）
    static let windowClosed = Notification.Name("windowClosed")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送应用启动完成的通知
    /// - Parameter object: 可选的对象参数
    static func postApplicationDidFinishLaunching(object: Any? = nil) {
        NotificationCenter.default.post(name: .applicationDidFinishLaunching, object: object)
    }

    /// 发送应用即将终止的通知
    /// - Parameter object: 可选的对象参数
    static func postApplicationWillTerminate(object: Any? = nil) {
        NotificationCenter.default.post(name: .applicationWillTerminate, object: object)
    }

    /// 发送应用变为活跃状态的通知
    /// - Parameter object: 可选的对象参数
    static func postApplicationDidBecomeActive(object: Any? = nil) {
        NotificationCenter.default.post(name: .applicationDidBecomeActive, object: object)
    }

    /// 发送应用变为非活跃状态的通知
    /// - Parameter object: 可选的对象参数
    static func postApplicationDidResignActive(object: Any? = nil) {
        NotificationCenter.default.post(name: .applicationDidResignActive, object: object)
    }

    /// 发送菜单栏外观更新请求
    /// - Parameters:
    ///   - isActive: 是否处于活跃/高亮状态
    ///   - source: 请求源标识符
    static func postRequestMenuBarAppearanceUpdate(isActive: Bool, source: String) {
        NotificationCenter.default.post(
            name: .requestMenuBarAppearanceUpdate,
            object: nil,
            userInfo: ["isActive": isActive, "source": source]
        )
    }

    /// 发送状态栏网速更新请求
    /// - Parameters:
    ///   - uploadSpeed: 上传速度（字节/秒）
    ///   - downloadSpeed: 下载速度（字节/秒）
    ///   - source: 请求源标识符
    static func postRequestStatusBarSpeedUpdate(uploadSpeed: Double, downloadSpeed: Double, source: String) {
        NotificationCenter.default.post(
            name: .requestStatusBarSpeedUpdate,
            object: nil,
            userInfo: ["uploadSpeed": uploadSpeed, "downloadSpeed": downloadSpeed, "source": source]
        )
    }

    /// 发送检查应用更新的通知
    /// - Parameter object: 可选的对象参数
    static func postCheckForUpdates(object: Any? = nil) {
        NotificationCenter.default.post(name: .checkForUpdates, object: object)
    }

    /// 发送应用更新已准备好安装的通知
    /// - Parameter version: 已下载更新版本号
    static func postAppUpdateReadyToInstall(version: String) {
        NotificationCenter.default.post(
            name: .appUpdateReadyToInstall,
            object: nil,
            userInfo: ["version": version]
        )
    }

    /// 发送安装已下载应用更新的通知
    static func postInstallPreparedAppUpdate() {
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
    }

    /// 发送文件拖放到聊天框的通知
    /// - Parameters:
    ///   - fileURL: 文件 URL
    ///   - windowId: 触发此操作的窗口 ID，用于多窗口场景下的事件隔离
    static func postFileDroppedToChat(fileURL: URL, windowId: UUID? = nil) {
        NotificationCenter.default.post(
            name: .fileDroppedToChat,
            object: nil,
            userInfo: [
                "fileURL": fileURL,
                "windowId": windowId as Any,
            ]
        )
    }

    /// 发送使用指定路由打开新窗口的通知
    /// - Parameter route: 窗口路由
    static func postOpenWindowWithRoute(route: LumiWindowRoute) {
        NotificationCenter.default.post(
            name: .openWindowWithRoute,
            object: nil,
            userInfo: ["route": route]
        )
    }

    /// 发送请求在当前活跃窗口编辑器中打开文件的通知
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - windowId: 目标窗口 ID，用于多窗口场景下的事件隔离
    static func postOpenFileInEditor(url: URL, windowId: UUID? = nil) {
        NotificationCenter.default.post(
            name: .openFileInEditor,
            object: nil,
            userInfo: [
                "url": url,
                "windowId": windowId as Any,
            ]
        )
    }

    /// 发送请求将当前窗口状态写入磁盘的通知
    static func postWindowStateShouldPersist() {
        NotificationCenter.default.post(name: .windowStateShouldPersist, object: nil)
    }

    /// 发送窗口关闭通知
    /// - Parameter windowId: 已关闭窗口的 ID
    static func postWindowClosed(_ windowId: UUID) {
        NotificationCenter.default.post(
            name: .windowClosed,
            object: windowId
        )
    }
}

// MARK: - View Extensions for Application Events

extension View {
    /// 监听应用启动完成的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onApplicationDidFinishLaunching(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidFinishLaunching)) { _ in
            action()
        }
    }

    /// 监听应用即将终止的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onApplicationWillTerminate(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationWillTerminate)) { _ in
            action()
        }
    }

    /// 监听应用变为活跃状态的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onApplicationDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidBecomeActive)) { _ in
            action()
        }
    }

    /// 监听应用变为非活跃状态的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onApplicationDidResignActive(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .applicationDidResignActive)) { _ in
            action()
        }
    }

    /// 监听检查应用更新的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onCheckForUpdates(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .checkForUpdates)) { _ in
            action()
        }
    }

    /// 监听状态栏网速更新的事件
    /// - Parameter action: 事件处理闭包，参数为 (uploadSpeed: Double, downloadSpeed: Double)
    /// - Returns: 修改后的视图
    func onStatusBarSpeedUpdate(perform action: @escaping (_ uploadSpeed: Double, _ downloadSpeed: Double) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .requestStatusBarSpeedUpdate)) { notification in
            guard let userInfo = notification.userInfo,
                  let upload = userInfo["uploadSpeed"] as? Double,
                  let download = userInfo["downloadSpeed"] as? Double else {
                return
            }
            action(upload, download)
        }
    }

    /// 监听文件拖放到聊天框的事件
    /// - Parameters:
    ///   - windowId: 可选的窗口 ID 过滤，仅处理来自指定窗口的通知
    ///   - action: 事件处理闭包，参数为文件 URL
    /// - Returns: 修改后的视图
    func onFileDroppedToChat(
        windowId: UUID? = nil,
        perform action: @escaping (URL) -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .fileDroppedToChat)) { notification in
            guard let userInfo = notification.userInfo,
                  let fileURL = userInfo["fileURL"] as? URL else {
                return
            }
            // 如果指定了窗口 ID，仅处理匹配的通知
            if let windowId {
                guard let senderWindowId = userInfo["windowId"] as? UUID,
                      senderWindowId == windowId else {
                    return
                }
            }
            action(fileURL)
        }
    }

    /// 监听使用指定路由打开新窗口的事件
    /// - Parameter action: 事件处理闭包，参数为窗口路由
    /// - Returns: 修改后的视图
    func onOpenWindowWithRoute(perform action: @escaping (LumiWindowRoute) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openWindowWithRoute)) { notification in
            guard let userInfo = notification.userInfo,
                  let route = userInfo["route"] as? LumiWindowRoute else {
                return
            }
            action(route)
        }
    }

    /// 监听在当前活跃窗口编辑器中打开文件的事件
    /// - Parameters:
    ///   - windowId: 可选的窗口 ID 过滤，仅处理来自指定窗口的通知
    ///   - action: 事件处理闭包，参数为文件 URL
    /// - Returns: 修改后的视图
    func onOpenFileInEditor(
        windowId: UUID? = nil,
        perform action: @escaping (URL) -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .openFileInEditor)) { notification in
            guard let userInfo = notification.userInfo,
                  let url = userInfo["url"] as? URL else {
                return
            }
            if let windowId {
                guard let senderWindowId = userInfo["windowId"] as? UUID,
                      senderWindowId == windowId else {
                    return
                }
            }
            action(url)
        }
    }

    /// 监听将当前窗口状态写入磁盘的事件
    /// - Parameter action: 事件处理闭包
    /// - Returns: 修改后的视图
    func onWindowStateShouldPersist(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .windowStateShouldPersist)) { _ in
            action()
        }
    }
}
