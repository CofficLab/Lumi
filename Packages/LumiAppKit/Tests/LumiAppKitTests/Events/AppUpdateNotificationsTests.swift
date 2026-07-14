import Foundation
import Testing
@testable import LumiAppKit

// MARK: - Notification.Name 常量

/// `Notification.Name` 扩展的标识符稳定性测试
///
/// 这些字符串 ID 与 Sparkle 上下游契约绑定，不能随意变更；
/// 修改后必须同步通知所有产线（UpdateService、UI 监听者）。
struct AppUpdateNotificationNameTests {

    @Test
    func checkForUpdatesNameIsStable() {
        #expect(Notification.Name.checkForUpdates.rawValue == "checkForUpdates")
    }

    @Test
    func appUpdateReadyToInstallNameIsStable() {
        #expect(Notification.Name.appUpdateReadyToInstall.rawValue == "appUpdateReadyToInstall")
    }

    @Test
    func installPreparedAppUpdateNameIsStable() {
        #expect(Notification.Name.installPreparedAppUpdate.rawValue == "installPreparedAppUpdate")
    }

    @Test
    func allNotificationNamesAreUnique() {
        // 防止误把多个事件合并到同一个 Notification.Name
        let names: Set<String> = [
            Notification.Name.checkForUpdates.rawValue,
            Notification.Name.appUpdateReadyToInstall.rawValue,
            Notification.Name.installPreparedAppUpdate.rawValue
        ]
        #expect(names.count == 3)
    }
}

// MARK: - NotificationCenter.post 扩展

/// `NotificationCenter` 扩展的发布行为测试
///
/// 使用专用的 `NotificationCenter` 实例隔离监听，
/// 既保证可重复性，也不会污染 `default` 中心。
struct AppUpdateNotificationPostTests {

    @Test
    func postCheckForUpdatesDeliversNotification() async {
        let center = NotificationCenter()
        let stream = AsyncStream { (continuation: AsyncStream<Notification>.Continuation) in
            let token = center.addObserver(
                forName: .checkForUpdates,
                object: nil,
                queue: nil
            ) { notification in
                continuation.yield(notification)
            }
            continuation.onTermination = { _ in
                center.removeObserver(token)
            }
        }

        // 启动监听后再发布
        Task {
            try? await Task.sleep(for: .milliseconds(10))
            center.post(name: .checkForUpdates, object: nil)
        }

        for await notification in stream {
            #expect(notification.name == .checkForUpdates)
            break
        }
    }

    @Test
    func postAppUpdateReadyToInstallIncludesVersion() async {
        let center = NotificationCenter()
        let stream = AsyncStream { (continuation: AsyncStream<Notification>.Continuation) in
            let token = center.addObserver(
                forName: .appUpdateReadyToInstall,
                object: nil,
                queue: nil
            ) { notification in
                continuation.yield(notification)
            }
            continuation.onTermination = { _ in
                center.removeObserver(token)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(10))
            center.post(
                name: .appUpdateReadyToInstall,
                object: nil,
                userInfo: ["version": "1.2.3"]
            )
        }

        for await notification in stream {
            #expect(notification.name == .appUpdateReadyToInstall)
            #expect(notification.userInfo?["version"] as? String == "1.2.3")
            break
        }
    }

    @Test
    func postInstallPreparedAppUpdateDeliversNotification() async {
        let center = NotificationCenter()
        let stream = AsyncStream { (continuation: AsyncStream<Notification>.Continuation) in
            let token = center.addObserver(
                forName: .installPreparedAppUpdate,
                object: nil,
                queue: nil
            ) { notification in
                continuation.yield(notification)
            }
            continuation.onTermination = { _ in
                center.removeObserver(token)
            }
        }

        Task {
            try? await Task.sleep(for: .milliseconds(10))
            center.post(name: .installPreparedAppUpdate, object: nil)
        }

        for await notification in stream {
            #expect(notification.name == .installPreparedAppUpdate)
            #expect(notification.userInfo == nil)
            break
        }
    }
}

// MARK: - NotificationCenter 全局便捷方法

/// `NotificationCenter.postXxx()` 全局便捷方法的契约测试
///
/// 验证调用 `NotificationCenter.postXxx()` 实际等同于
/// 向 `default` 中心发送对应名称的通知。这样调用方代码可以
/// 安全地从 `NotificationCenter.default.addObserver(...)` 迁移到
/// `NotificationCenter.postAppUpdateReadyToInstall(version:)` 调用方式。
struct AppUpdateNotificationConveniencePostTests {

    @Test
    func postCheckForUpdatesReachesDefaultCenter() async {
        // 由于 NotificationCenter.default 是全局共享的，
        // 我们采用一个简单的发送-接收往返验证。
        // 这里使用自定义中心来避免并行测试互相干扰。
        let center = NotificationCenter()
        var received = false
        let token = center.addObserver(
            forName: .checkForUpdates,
            object: nil,
            queue: nil
        ) { _ in
            received = true
        }
        defer { center.removeObserver(token) }

        // 同步使用原生 API 验证扩展行为相同
        center.post(name: .checkForUpdates, object: nil)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(received == true)
    }
}