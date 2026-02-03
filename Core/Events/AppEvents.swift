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

    /// 请求更新状态栏外观的通知
    /// userInfo: ["isActive": Bool, "source": String]
    static let requestStatusBarAppearanceUpdate = Notification.Name("requestStatusBarAppearanceUpdate")

    /// 请求更新状态栏网速显示的通知
    /// userInfo: ["uploadSpeed": Double, "downloadSpeed": Double, "source": String]
    static let requestStatusBarSpeedUpdate = Notification.Name("requestStatusBarSpeedUpdate")

    /// 检查应用更新的通知
    static let checkForUpdates = Notification.Name("checkForUpdates")
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

    /// 发送状态栏外观更新请求
    /// - Parameters:
    ///   - isActive: 是否处于活跃/高亮状态
    ///   - source: 请求源标识符
    static func postRequestStatusBarAppearanceUpdate(isActive: Bool, source: String) {
        NotificationCenter.default.post(
            name: .requestStatusBarAppearanceUpdate,
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
}
