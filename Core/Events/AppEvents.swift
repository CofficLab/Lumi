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
}
