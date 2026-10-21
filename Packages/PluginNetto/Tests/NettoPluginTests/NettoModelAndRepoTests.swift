import Foundation
import Testing
@testable import NettoPlugin

// MARK: - 临时目录助手

/// 为每个用例提供独立的临时目录，避免用例之间互相污染。
private struct TempDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NettoPluginTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func fileURL(_ name: String = "settings.json") -> URL {
        url.appendingPathComponent(name)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 设置仓库

@Suite("Netto 设置仓库")
struct AppSettingRepoTests {

    @Test("文件不存在时设置保持为空")
    func loadsEmptyWhenFileMissing() {
        let temp = TempDirectory()
        defer { temp.cleanup() }

        let repo = AppSettingRepo(fileURL: temp.fileURL())

        #expect(repo.settings.isEmpty)
    }

    @Test("合法 JSON 被还原成按 appId 索引的设置")
    func loadsPersistedSettings() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL()
        let data = try JSONEncoder().encode([
            AppSetting(appId: "com.apple.Safari", allowed: true),
            AppSetting(appId: "com.example.Blocked", allowed: false),
        ])
        try data.write(to: url)

        let repo = AppSettingRepo(fileURL: url)

        #expect(repo.settings.count == 2)
        #expect(repo.settings["com.apple.Safari"]?.allowed == true)
        #expect(repo.settings["com.example.Blocked"]?.allowed == false)
    }

    @Test("损坏的文件被移为 .corrupt 且设置清空")
    func preservesCorruptFile() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL()
        try Data("not json".utf8).write(to: url)

        let repo = AppSettingRepo(fileURL: url)

        #expect(repo.settings.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    @Test("重复损坏时旧的 .corrupt 备份被覆盖")
    func overwritesExistingCorruptBackup() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL()
        let backup = url.appendingPathExtension("corrupt")
        try Data("old".utf8).write(to: backup)
        try Data("not json".utf8).write(to: url)

        _ = AppSettingRepo(fileURL: url)

        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(try Data(contentsOf: backup).isEmpty == false)
    }

    @Test("保存后能再次读回同样的设置")
    func savesAndReloads() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL()
        let repo = AppSettingRepo(fileURL: url)

        repo.setAllowed(appId: "com.example.app", allowed: false)
        repo.setAllowed(appId: "com.example.other", allowed: true)

        let reloaded = AppSettingRepo(fileURL: url)
        #expect(reloaded.settings.count == 2)
        #expect(reloaded.getSetting(for: "com.example.app")?.allowed == false)
        #expect(reloaded.getSetting(for: "com.example.other")?.allowed == true)
    }

    @Test("保存会创建缺失的目录")
    func createsMissingDirectory() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL("nested/dir/settings.json")
        let repo = AppSettingRepo(fileURL: url, loadImmediately: false)

        repo.setAllowed(appId: "com.example.app", allowed: true)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("更新设置会覆盖同 appId 的旧值")
    func updateReplacesExisting() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let repo = AppSettingRepo(fileURL: temp.fileURL(), loadImmediately: false)

        repo.updateSetting(AppSetting(appId: "com.example.app", allowed: true))
        repo.updateSetting(AppSetting(appId: "com.example.app", allowed: false))

        #expect(repo.settings.count == 1)
        #expect(repo.getSetting(for: "com.example.app")?.allowed == false)
    }

    @Test("未配置的应用默认放行")
    func defaultsToAllowed() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let repo = AppSettingRepo(fileURL: temp.fileURL(), loadImmediately: false)

        #expect(repo.isAllowed(appId: "com.unknown.app"))
    }

    @Test("已配置的应用按设置返回")
    func isAllowedReflectsSetting() {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let repo = AppSettingRepo(fileURL: temp.fileURL(), loadImmediately: false)

        repo.setAllowed(appId: "com.blocked.app", allowed: false)

        #expect(repo.isAllowed(appId: "com.blocked.app") == false)
        #expect(repo.isAllowed(appId: "com.other.app"))
    }

    @Test("延迟加载时不主动读盘")
    func supportsDeferringLoad() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let url = temp.fileURL()
        try JSONEncoder().encode([AppSetting(appId: "com.a", allowed: false)]).write(to: url)

        let repo = AppSettingRepo(fileURL: url, loadImmediately: false)
        #expect(repo.settings.isEmpty)

        repo.load()
        #expect(repo.settings.count == 1)
    }
}

// MARK: - 数据模型

@Suite("Netto 数据模型")
struct NettoModelTests {

    @Test("应用设置的 id 就是 appId")
    func appSettingIdentity() {
        let setting = AppSetting(appId: "com.example.app", allowed: true)

        #expect(setting.id == "com.example.app")
        #expect(setting.allowed)
    }

    @Test("应用设置可编解码")
    func appSettingCodable() throws {
        let setting = AppSetting(appId: "com.example.app", allowed: false)
        let data = try JSONEncoder().encode(setting)

        #expect(try JSONDecoder().decode(AppSetting.self, from: data) == setting)
    }

    @Test("防火墙事件描述地址与端口")
    func firewallEventDescription() {
        let event = FirewallEvent(
            address: "example.com",
            port: "443",
            status: .allowed,
            direction: .outbound
        )

        #expect(event.description == "example.com:443")
        #expect(event.isAllowed)
        #expect(event.statusDescription == "Allowed")
        #expect(event.timeFormatted.isEmpty == false)
    }

    @Test("被拦截的事件状态为 Blocked")
    func firewallEventRejected() {
        let event = FirewallEvent(
            address: "ads.example.com",
            port: "80",
            status: .rejected,
            direction: .inbound
        )

        #expect(event.isAllowed == false)
        #expect(event.statusDescription == "Blocked")
    }

    @Test("防火墙事件默认带 id 与时间")
    func firewallEventDefaults() {
        let event = FirewallEvent(
            address: "example.com",
            port: "443",
            status: .allowed,
            direction: .any
        )

        #expect(event.id.isEmpty == false)
        #expect(event.timeFormatted.isEmpty == false)
        #expect(event.sourceAppIdentifier.isEmpty)
    }

    @Test("两个事件默认 id 互不相同")
    func firewallEventUniqueIdentifiers() {
        let first = FirewallEvent(address: "a", port: "1", status: .allowed, direction: .any)
        let second = FirewallEvent(address: "b", port: "2", status: .allowed, direction: .any)

        #expect(first.id != second.id)
    }

    @Test("智能应用的派生属性")
    func smartAppDerivedProperties() {
        let app = SmartApp(id: "com.example.app", name: "Example")

        #expect(app.hasId)
        #expect(app.hasNoId == false)
        #expect(app.isNotSample)
        #expect(app.isSystemApp == false)
        #expect(app.hidden == false)
        #expect(app.isProxy == false)
    }

    @Test("智能应用的相等性按字段比较")
    func smartAppEquatable() {
        let first = SmartApp(id: "com.example.app", name: "Example")
        let second = SmartApp(id: "com.example.app", name: "Example")
        let third = SmartApp(id: "com.example.other", name: "Other")

        #expect(first == second)
        #expect(first != third)
    }

    @Test("未知应用回退为用 id 命名的条目")
    func smartAppFromUnknownId() {
        let app = SmartApp.fromId("com.coffic.unknown.app")

        #expect(app.id == "com.coffic.unknown.app")
        #expect(app.name == "com.coffic.unknown.app")
        #expect(app.bundleURL == nil)
    }

    @Test("已知代理应用被识别")
    func detectsKnownProxyApps() {
        #expect(SmartApp.isProxyApp(withId: "com.expressvpn.ExpressVPN"))
        #expect(SmartApp.isProxyApp(withId: "com.nordvpn.osx"))
        #expect(SmartApp.isProxyApp(withId: "net.tunnelblick.tunnelblick"))
    }

    @Test("含代理关键词的 bundle id 被识别")
    func detectsProxyByBundleIdentifierKeyword() {
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.MyVPNClient"))
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.clashX"))
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.someProxy"))
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.wireguardTunnel"))
    }

    @Test("只匹配应用名称也能识别代理")
    func detectsProxyByNameKeyword() {
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.unknown", name: "ShadowSocksX"))
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.unknown", name: "Some V2Ray App"))
    }

    @Test("普通应用不被识别为代理")
    func ignoresRegularApps() {
        #expect(SmartApp.isProxyApp(withId: "com.apple.Safari") == false)
        #expect(SmartApp.isProxyApp(withId: "com.apple.Terminal", name: "Terminal") == false)
        #expect(SmartApp.isProxyApp(withId: "com.mycompany.notes", name: "Notes") == false)
    }
}

// MARK: - 状态展示

@Suite("Netto 过滤器状态")
struct FilterStatusTests {

    @Test("状态带可读文案")
    func statusDescriptions() {
        #expect(FilterStatus.stopped.description == "Stopped")
        #expect(FilterStatus.running.description == "Running")
        #expect(FilterStatus.error.description == "Error")
        #expect(FilterStatus.indeterminate.description == "Loading...")
    }

    @Test("状态可枚举")
    func statusIsCaseIterable() {
        #expect(FilterStatus.allCases.count == 4)
    }
}
