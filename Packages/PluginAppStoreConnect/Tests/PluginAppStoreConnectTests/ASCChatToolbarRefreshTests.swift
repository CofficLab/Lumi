import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归 #320：Chat Toolbar 手动刷新必须把 forceRefresh 一路传到能力边界，
/// 让 App 解析与版本列表都绕过缓存走网络，而不是只刷新本地绑定字典。
@Suite(.serialized)
@MainActor
struct ASCChatToolbarRefreshTests {

    // MARK: - Doubles

    /// 记录每个查询收到的 forceRefresh 标志。
    private final class RecordingCapability: ASCChatClientCapability {
        var appsByBundleID: [String: AppStoreApp] = [:]
        var appsByID: [String: AppStoreApp] = [:]
        var versionsByAppID: [String: [AppStoreVersion]] = [:]
        var findAppFlags: [Bool] = []
        var readAppFlags: [Bool] = []
        var listVersionsFlags: [Bool] = []

        func findApp(bundleID: String, forceRefresh: Bool) async throws -> AppStoreApp? {
            findAppFlags.append(forceRefresh)
            return appsByBundleID[bundleID]
        }

        func readApp(id: String, forceRefresh: Bool) async throws -> AppStoreApp {
            readAppFlags.append(forceRefresh)
            guard let app = appsByID[id] else { throw ASCChatClientError.unavailable }
            return app
        }

        func listVersions(appID: String, forceRefresh: Bool) async throws -> [AppStoreVersion] {
            listVersionsFlags.append(forceRefresh)
            return versionsByAppID[appID] ?? []
        }
    }

    // MARK: - Helpers

    private func makeProjectDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ASCChatToolbarRefreshTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeAppConfiguration(projectPath: String, json: String) {
        let directory = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(".lumi/app-store-connect", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? json.write(
            to: directory.appendingPathComponent("app.json"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func makeApp(id: String, bundleID: String) -> AppStoreApp {
        AppStoreApp(
            id: id,
            name: "Demo",
            bundleID: bundleID,
            sku: "DEMO",
            primaryLocale: "en-US",
            platform: "IOS"
        )
    }

    private func makeVersion(id: String, versionString: String) -> AppStoreVersion {
        AppStoreVersion(
            id: id,
            platform: "IOS",
            versionString: versionString,
            appStoreState: "READY_FOR_SALE",
            appVersionState: "RELEASED",
            createdDate: nil
        )
    }

    private func waitUntilSettled(
        _ viewModel: ASCChatToolbarViewModel,
        timeout: Duration = .seconds(3)
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if !viewModel.isLoading { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - Tests

    @Test("appID 绑定时刷新强制 App 读取与版本列表都走网络")
    func refreshForcesNetworkOnAppIDBinding() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        writeAppConfiguration(projectPath: project.path, json: #"{"appID": "app-1"}"#)

        let client = RecordingCapability()
        client.appsByID["app-1"] = makeApp(id: "app-1", bundleID: "com.example.demo")
        client.versionsByAppID["app-1"] = [makeVersion(id: "v1", versionString: "1.0.0")]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)
        #expect(client.readAppFlags == [false])
        #expect(client.listVersionsFlags == [false])

        await viewModel.refresh()
        #expect(client.readAppFlags == [false, true])
        #expect(client.listVersionsFlags == [false, true])
    }

    @Test("bundleID 绑定时刷新强制 App 查询与版本列表都走网络")
    func refreshForcesNetworkOnBundleIDBinding() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        writeAppConfiguration(projectPath: project.path, json: #"{"bundleID": "com.example.demo"}"#)

        let client = RecordingCapability()
        client.appsByBundleID["com.example.demo"] = makeApp(id: "app-1", bundleID: "com.example.demo")
        client.versionsByAppID["app-1"] = [makeVersion(id: "v1", versionString: "1.0.0")]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)
        #expect(client.findAppFlags == [false])
        #expect(client.listVersionsFlags == [false])

        await viewModel.refresh()
        #expect(client.findAppFlags == [false, true])
        #expect(client.listVersionsFlags == [false, true])
    }

    @Test("首次加载沿用缓存优先，不强制走网络")
    func initialLoadUsesCacheFirst() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        writeAppConfiguration(projectPath: project.path, json: #"{"appID": "app-1"}"#)

        let client = RecordingCapability()
        client.appsByID["app-1"] = makeApp(id: "app-1", bundleID: "com.example.demo")
        client.versionsByAppID["app-1"] = [makeVersion(id: "v1", versionString: "1.0.0")]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)

        #expect(client.readAppFlags == [false])
        #expect(client.listVersionsFlags == [false])
        #expect(viewModel.versionCount == 1)
    }
}