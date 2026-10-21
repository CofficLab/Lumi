import Foundation
import KernelCore
import KitTestIsolation
import ProviderAppUpdate
import ProviderNetwork
import ProviderStorage
import Testing
@testable import AppUpdatePlugin

// MARK: - 本地存储

@Suite("App update 本地存储")
struct AppUpdatePluginLocalStoreTests {

    @Test("新实例默认返回 stable 通道")
    func defaultsToStableChannel() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("store-default")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)

        #expect(store.channel == .stable)
    }

    @Test("写入 preview 后读回 preview")
    func roundTripsPreviewChannel() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("store-preview")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)

        store.setChannel(.preview)

        #expect(store.channel == .preview)
    }

    @Test("写入后在设置目录落下 settings.plist")
    func writesSettingsPlist() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("store-file")
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)

        store.setChannel(.preview)

        let file = directory.appendingPathComponent("settings.plist")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("内容损坏时回退到 stable")
    func fallsBackToStableOnCorruptedFile() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("store-corrupt")
        let file = directory.appendingPathComponent("settings.plist")
        try? Data("not a plist".utf8).write(to: file)

        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)

        #expect(store.channel == .stable)
    }

    @Test("未知通道值回退到 stable")
    func fallsBackToStableOnUnknownChannel() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("store-unknown")
        let file = directory.appendingPathComponent("settings.plist")
        let payload = try? PropertyListSerialization.data(
            fromPropertyList: [AppUpdateChannel.userDefaultsKey: "nightly"],
            format: .binary,
            options: 0
        )
        try? payload?.write(to: file)

        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)

        #expect(store.channel == .stable)
    }

    @Test("不存在的设置目录会被自动创建")
    func createsMissingDirectory() {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("store-missing")
        let directory = root.appendingPathComponent("nested", isDirectory: true)

        _ = AppUpdatePluginLocalStore(settingsDirectory: directory)

        #expect(FileManager.default.fileExists(atPath: directory.path))
    }
}

// MARK: - 运行时目录

@Suite("App update 运行时目录")
@MainActor
struct AppUpdateRuntimeTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesInjectedDirectory() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("runtime-injected")
        AppUpdateRuntime.configure(settingsDirectory: directory)
        defer { AppUpdateRuntime.reset() }

        #expect(AppUpdateRuntime.settingsDirectory() == directory)
    }

    @Test("重置后清空注入目录，不再回退到真实数据目录")
    func resetClearsInjectedDirectory() {
        let directory = AppUpdateTestDoubles.makeTemporaryDirectory("runtime-reset")
        AppUpdateRuntime.configure(settingsDirectory: directory)
        AppUpdateRuntime.reset()
        defer { AppUpdateRuntime.reset() }

        #expect(AppUpdateRuntime.injectedSettingsDirectory == nil)

        // 重置之后不得再回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: AppUpdateRuntime.injectedSettingsDirectory,
            owner: "AppUpdateRuntime",
            accessor: "settingsDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/app-update-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("AppUpdateRuntime"))
            #expect(reason.contains("settingsDirectory()"))
        }
    }
}

// MARK: - 通知

/// 通知用例必须与包内其它投递同名通知的用例串行：本文件与
/// `UpdateRequestObserverTests` 共用 `NotificationCenter.default`，
/// 并发投递同名通知会互相干扰计数。
@Suite("App update 通知", .serialized)
@MainActor
struct AppUpdateNotificationTests {

    @Test("保留历史通知名字符串")
    func keepsNotificationNames() {
        #expect(Notification.Name.checkForUpdates.rawValue == "checkForUpdates")
        #expect(Notification.Name.appUpdateReadyToInstall.rawValue == "appUpdateReadyToInstall")
        #expect(Notification.Name.installPreparedAppUpdate.rawValue == "installPreparedAppUpdate")
    }

    @Test("postCheckForUpdates 广播同名通知")
    func postsCheckForUpdates() async {
        let received = NotificationRecorder()

        // 观察者必须在门闩内注册：否则别的 suite 在本用例等待期间投递的
        // 同名通知也会被本用例的观察者收到。
        await AppUpdateNotificationGate.acquire()
        let token = NotificationCenter.default.addObserver(
            forName: .checkForUpdates,
            object: nil,
            queue: .main
        ) { _ in received.increment() }

        NotificationCenter.postCheckForUpdates()
        await received.waitForDelivery()
        #expect(received.value == 1, Comment("实际收到 \(received.value) 次"))

        NotificationCenter.default.removeObserver(token)
        await AppUpdateNotificationGate.release()
    }

    @Test("postAppUpdateReadyToInstall 携带版本号")
    func postsReadyToInstallWithVersion() async {
        let received = NotificationRecorder()

        await AppUpdateNotificationGate.acquire()
        let token = NotificationCenter.default.addObserver(
            forName: .appUpdateReadyToInstall,
            object: nil,
            queue: .main
        ) { notification in
            received.increment()
            received.setVersion(notification.userInfo?["version"] as? String)
        }

        NotificationCenter.postAppUpdateReadyToInstall(version: "5.2.1")
        await received.waitForDelivery()
        #expect(received.version == "5.2.1", Comment("实际收到 \(received.value) 次"))

        NotificationCenter.default.removeObserver(token)
        await AppUpdateNotificationGate.release()
    }

    @Test("postInstallPreparedAppUpdate 广播同名通知")
    func postsInstallPrepared() async {
        let received = NotificationRecorder()

        await AppUpdateNotificationGate.acquire()
        let token = NotificationCenter.default.addObserver(
            forName: .installPreparedAppUpdate,
            object: nil,
            queue: .main
        ) { _ in received.increment() }

        NotificationCenter.postInstallPreparedAppUpdate()
        await received.waitForDelivery()
        #expect(received.value == 1, Comment("实际收到 \(received.value) 次"))

        NotificationCenter.default.removeObserver(token)
        await AppUpdateNotificationGate.release()
    }
}

// MARK: - Feed URL

@Suite("App update feed URL")
struct UpdateFeedURLProviderTests {

    @Test("stable 通道主源与回退源指向各自域名")
    func stableChannelURLs() {
        let primary = UpdateFeedURLProvider.primary(for: .stable, architecture: "arm64")
        let fallback = UpdateFeedURLProvider.fallback(for: .stable, architecture: "arm64")

        #expect(primary.absoluteString == "https://s.kuaiyizhi.cn/lumi/appcast-arm64.xml")
        #expect(
            fallback.absoluteString
                == "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-arm64.xml"
        )
    }

    @Test("preview 通道主源走 pre 目录")
    func previewChannelPrimary() {
        let primary = UpdateFeedURLProvider.primary(for: .preview, architecture: "x86_64")

        #expect(primary.absoluteString == "https://s.kuaiyizhi.cn/lumi/pre/appcast-pre-x86_64.xml")
    }

    @Test("preview 通道回退源走 raw.githubusercontent 的 pre 目录")
    func previewChannelFallback() {
        let fallback = UpdateFeedURLProvider.fallback(for: .preview, architecture: "x86_64")

        #expect(
            fallback.absoluteString
                == "https://raw.githubusercontent.com/CofficLab/Lumi/pre/appcast-pre-x86_64.xml"
        )
    }

    @Test("无参入口等价于 stable 通道 + 当前架构")
    func noArgumentEntryPoints() {
        #expect(UpdateFeedURLProvider.primary == UpdateFeedURLProvider.primary(for: .stable))
        #expect(UpdateFeedURLProvider.fallback == UpdateFeedURLProvider.fallback(for: .stable))
        #expect(
            UpdateFeedURLProvider.primary(forArchitecture: "arm64")
                == UpdateFeedURLProvider.primary(for: .stable, architecture: "arm64")
        )
    }
}

// MARK: - 网络可达性

@Suite("App update 网络可达性")
struct ProviderNetworkReachabilityCheckerTests {

    @Test("200 视为可达，且使用 HEAD 与指定超时")
    func treats200AsReachable() async {
        let network = AppUpdateTestDoubles.StubNetworkProvider(statusCode: 200)
        let checker = ProviderNetworkReachabilityChecker(network: network, timeout: 7)
        let url = URL(string: "https://example.com/appcast.xml")!

        let reachable = await checker.isReachable(url)

        #expect(reachable)
        let recorded = network.requests
        #expect(recorded.count == 1)
        #expect(recorded.first?.method == .head)
        #expect(recorded.first?.timeout == 7)
        #expect(recorded.first?.url == url)
    }

    @Test("非 200 视为不可达")
    func treatsNon200AsUnreachable() async {
        let network = AppUpdateTestDoubles.StubNetworkProvider(statusCode: 404)
        let checker = ProviderNetworkReachabilityChecker(network: network)

        let reachable = await checker.isReachable(URL(string: "https://example.com/appcast.xml")!)

        #expect(reachable == false)
    }

    @Test("请求抛错视为不可达")
    func treatsErrorAsUnreachable() async {
        let network = AppUpdateTestDoubles.StubNetworkProvider(failure: StubNetworkError())
        let checker = ProviderNetworkReachabilityChecker(network: network)

        let reachable = await checker.isReachable(URL(string: "https://example.com/appcast.xml")!)

        #expect(reachable == false)
    }
}

// MARK: - 运行环境

@Suite("App update 运行环境")
struct AppUpdateRuntimeEnvironmentTests {

    @Test("没有 Info.plist 开关时按 bundleIdentifier 判定")
    func fallsBackToBundleIdentifier() {
        let environment = AppUpdateRuntimeEnvironment()
        let identifier = Bundle.main.bundleIdentifier ?? ""

        #expect(environment.allowsAppUpdates == !identifier.hasPrefix("com.coffic.lumi.debug"))
    }
}

// MARK: - 宿主引导

@Suite("App update 宿主引导", .serialized)
@MainActor
struct AppUpdateBootstrapTests {

    @Test("启动后注册更新通道 Provider")
    func registersChannelProvider() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-register")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        #expect(kernel.resolveProvider((any AppUpdateChannelProviding).self) != nil)
    }

    @Test("启动时把存储目录注入运行时配置")
    func injectsStorageDirectory() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-directory")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        let expected = root.appendingPathComponent(
            AppUpdateBootstrap.pluginID,
            isDirectory: true
        )
        #expect(AppUpdateRuntime.settingsDirectory() == expected)
    }

    @Test("停止后注销更新通道 Provider")
    func unregistersChannelProviderOnStop() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-stop")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        AppUpdateBootstrap.start(kernel: kernel)
        AppUpdateBootstrap.stop()

        #expect(kernel.resolveProvider((any AppUpdateChannelProviding).self) == nil)
    }

    @Test("同一个 kernel 重复启动不会重复注册 Provider")
    func repeatedStartKeepsSingleProvider() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-repeat")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        AppUpdateBootstrap.start(kernel: kernel)
        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        #expect(kernel.resolveProvider((any AppUpdateChannelProviding).self) != nil)
    }

    @Test("注册网络 Provider 时把网络注入更新服务")
    func configuresNetworkProvider() async throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-network")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )
        let network = AppUpdateTestDoubles.StubNetworkProvider(statusCode: 200)
        try kernel.registerProvider((any NetworkProviding).self, network)

        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        // 启动流程会准备 feed URL，探测请求走注册的 Provider。
        try await Task.sleep(for: .milliseconds(200))

        #expect(network.requests.isEmpty == false)
    }

    @Test("legacy UserDefaults 通道在插件存储为空时被导入")
    func importsLegacyChannel() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-legacy")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        UserDefaults.standard.set("preview", forKey: AppUpdateChannel.userDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: AppUpdateChannel.userDefaultsKey) }

        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        let directory = root.appendingPathComponent(AppUpdateBootstrap.pluginID, isDirectory: true)
        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        #expect(store.channel == .preview)
    }

    @Test("插件存储已有记录时不覆盖 legacy 通道")
    func keepsExistingChannelOverLegacy() throws {
        let root = AppUpdateTestDoubles.makeTemporaryDirectory("bootstrap-existing")
        let directory = root.appendingPathComponent(AppUpdateBootstrap.pluginID, isDirectory: true)
        AppUpdatePluginLocalStore(settingsDirectory: directory).setChannel(.stable)

        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            AppUpdateTestDoubles.StubStorageProvider(root: root)
        )

        UserDefaults.standard.set("preview", forKey: AppUpdateChannel.userDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: AppUpdateChannel.userDefaultsKey) }

        AppUpdateBootstrap.start(kernel: kernel)
        defer { AppUpdateBootstrap.stop() }

        let store = AppUpdatePluginLocalStore(settingsDirectory: directory)
        #expect(store.channel == .stable)
    }

    @Test("未启动就停止是安全的")
    func stopWithoutStartIsSafe() {
        AppUpdateBootstrap.stop()

        #expect(AppUpdateBootstrap.pluginID == "com.coffic.lumi.plugin.app-update")
    }
}

// MARK: - 辅助替身

/// 记录通知次数与版本号的辅助对象。
private final class NotificationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var storedVersion: String?

    var value: Int {
        lock.withLock { count }
    }

    var version: String? {
        lock.withLock { storedVersion }
    }

    func increment() {
        lock.withLock { count += 1 }
    }

    func setVersion(_ value: String?) {
        lock.withLock { storedVersion = value }
    }

    /// 等待通知真正送达。
    ///
    /// `queue: .main` 的投递时机取决于当前线程与主队列的关系，这里改为轮询
    /// 计数变化，避免依赖固定睡眠长度。
    func waitForDelivery(timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if value > 0 { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// 网络替身使用的哨兵错误。
private struct StubNetworkError: Error {}
