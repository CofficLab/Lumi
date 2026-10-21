import Foundation
import NetworkExtension
import Testing
@testable import NettoPlugin

// MARK: - 临时目录助手

/// 为每个用例提供独立的临时目录。
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

// MARK: - ViewModel

@Suite("Netto ViewModel")
@MainActor
struct NettoViewModelTests {

    private func makeContext() -> (FirewallService, AppSettingRepo, NettoViewModel, TempDirectory) {
        let temp = TempDirectory()
        // FirewallService 内部持有 AppSettingRepo.shared：先注入隔离目录，
        // 否则守卫会拒绝并杀掉整个测试进程。
        NettoSharedRepoIsolation.install()
        let service = FirewallService()
        let repo = AppSettingRepo(fileURL: temp.fileURL(), loadImmediately: false)
        let viewModel = NettoViewModel(service: service, repo: repo)
        return (service, repo, viewModel, temp)
    }

    @Test("初始状态为未定且没有事件")
    func initialState() {
        let (_, _, viewModel, temp) = makeContext()
        defer { temp.cleanup() }

        #expect(viewModel.status == .indeterminate)
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.settings.isEmpty)
    }

    @Test("同步服务状态后拿到状态与事件")
    func appliesServiceState() {
        let (service, _, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        let event = FirewallEvent(address: "example.com", port: "443", status: .allowed, direction: .outbound)
        service.status = .running
        service.events = [event]

        viewModel.applyServiceState()

        #expect(viewModel.status == .running)
        #expect(viewModel.events.count == 1)
        #expect(viewModel.events.first?.address == "example.com")
    }

    @Test("同步设置后拿到按 appId 索引的设置")
    func appliesSettings() {
        let (_, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        repo.settings = ["com.example.app": AppSetting(appId: "com.example.app", allowed: false)]

        viewModel.applySettings()

        #expect(viewModel.settings.count == 1)
        #expect(viewModel.settings["com.example.app"]?.allowed == false)
    }

    @Test("未配置的应用默认放行")
    func isAllowedDefaultsToTrue() {
        let (_, _, viewModel, temp) = makeContext()
        defer { temp.cleanup() }

        #expect(viewModel.isAllowed(appId: "com.unknown.app"))
    }

    @Test("已配置的应用按设置返回")
    func isAllowedReflectsSettings() {
        let (_, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        repo.settings = ["com.blocked.app": AppSetting(appId: "com.blocked.app", allowed: false)]
        viewModel.applySettings()

        #expect(viewModel.isAllowed(appId: "com.blocked.app") == false)
    }

    @Test("设置放行状态会写回仓库并刷新视图")
    func setAllowedWritesBack() {
        let (_, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }

        viewModel.setAllowed(appId: "com.example.app", allowed: false)

        #expect(repo.getSetting(for: "com.example.app")?.allowed == false)
        #expect(viewModel.settings["com.example.app"]?.allowed == false)
        #expect(viewModel.isAllowed(appId: "com.example.app") == false)
    }
}

// MARK: - 观察者

@Suite("Netto 观察者")
@MainActor
struct NettoObserverTests {

    private func makeContext() -> (FirewallService, AppSettingRepo, NettoViewModel, TempDirectory) {
        let temp = TempDirectory()
        // FirewallService 内部持有 AppSettingRepo.shared：先注入隔离目录，
        // 否则守卫会拒绝并杀掉整个测试进程。
        NettoSharedRepoIsolation.install()
        let service = FirewallService()
        let repo = AppSettingRepo(fileURL: temp.fileURL(), loadImmediately: false)
        let viewModel = NettoViewModel(service: service, repo: repo)
        return (service, repo, viewModel, temp)
    }

    @Test("初始化时立即同步服务状态与设置")
    func syncsOnInit() {
        let (service, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        service.status = .running
        repo.settings = ["com.example.app": AppSetting(appId: "com.example.app", allowed: false)]

        _ = NettoObserver(viewModel: viewModel, service: service, repo: repo)

        #expect(viewModel.status == .running)
        #expect(viewModel.settings.count == 1)
    }

    @Test("服务状态变化后视图跟着刷新")
    func refreshesOnServiceChange() {
        let (service, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        let observer = NettoObserver(viewModel: viewModel, service: service, repo: repo)

        service.status = .error
        service.events = [
            FirewallEvent(address: "ads.example.com", port: "80", status: .rejected, direction: .outbound),
        ]

        #expect(viewModel.status == .error)
        #expect(viewModel.events.count == 1)
        observer.cancel()
    }

    @Test("设置变化后视图跟着刷新")
    func refreshesOnRepoChange() {
        let (service, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        let observer = NettoObserver(viewModel: viewModel, service: service, repo: repo)

        repo.settings = ["com.example.app": AppSetting(appId: "com.example.app", allowed: false)]

        #expect(viewModel.settings.count == 1)
        observer.cancel()
    }

    @Test("取消后不再跟随服务状态变化")
    func stopsUpdatingAfterCancel() {
        let (service, repo, viewModel, temp) = makeContext()
        defer { temp.cleanup() }
        let observer = NettoObserver(viewModel: viewModel, service: service, repo: repo)

        observer.cancel()
        service.status = .error

        #expect(viewModel.status == .indeterminate)
    }
}
