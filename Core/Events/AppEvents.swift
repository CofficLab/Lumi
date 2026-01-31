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
