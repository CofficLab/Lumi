import Foundation
import Testing
@testable import PluginAppStoreConnect

/// Chat Toolbar ASC 面板的 ViewModel 行为。
@Suite(.serialized)
@MainActor
struct ASCChatToolbarViewModelTests {

    // MARK: - Doubles

    /// 测试替身：记录调用并返回预设结果。
    private final class StubClientCapability: ASCChatClientCapability {
        var appsByBundleID: [String: AppStoreApp] = [:]
        var appsByID: [String: AppStoreApp] = [:]
        var versionsByAppID: [String: [AppStoreVersion]] = [:]
        var findAppCallCount = 0
        var readAppCallCount = 0
        var listVersionsCallCount = 0

        func findApp(bundleID: String) async throws -> AppStoreApp? {
            findAppCallCount += 1
            return appsByBundleID[bundleID]
        }

        func readApp(id: String) async throws -> AppStoreApp {
            readAppCallCount += 1
            guard let app = appsByID[id] else {
                throw ASCChatClientError.unavailable
            }
            return app
        }

        func listVersions(appID: String) async throws -> [AppStoreVersion] {
            listVersionsCallCount += 1
            return versionsByAppID[appID] ?? []
        }
    }

    // MARK: - Helpers

    private func makeProjectDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ASCChatToolbarViewModelTests-\(UUID().uuidString)", isDirectory: true)
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

    /// 等待 ViewModel 完成一次异步解析。
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

    @Test("a project without any binding reports no binding")
    func projectWithoutBindingReportsNoBinding() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        let client = StubClientCapability()
        let viewModel = ASCChatToolbarViewModel(clientCapability: client)

        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)

        #expect(viewModel.hasBinding == false)
        #expect(viewModel.app == nil)
        #expect(viewModel.versions.isEmpty)
        #expect(client.findAppCallCount == 0)
    }

    @Test("app id binding loads the app and its versions")
    func appIDBindingLoadsVersions() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(projectPath: project.path, json: #"{"appID": "6758871065"}"#)

        let client = StubClientCapability()
        client.appsByID["6758871065"] = makeApp(id: "6758871065", bundleID: "com.example.demo")
        client.versionsByAppID["6758871065"] = [
            makeVersion(id: "v1", versionString: "1.0.0"),
            makeVersion(id: "v2", versionString: "1.1.0"),
        ]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)

        #expect(viewModel.hasBinding == true)
        #expect(viewModel.binding?.appID == "6758871065")
        #expect(viewModel.app?.id == "6758871065")
        #expect(viewModel.versionCount == 2)
        #expect(client.readAppCallCount == 1)
        // appID 已确定时不应再走 bundle ID 查询。
        #expect(client.findAppCallCount == 0)
    }

    @Test("bundle id binding resolves the app through the client")
    func bundleIDBindingResolvesApp() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(
            projectPath: project.path,
            json: #"{"bundleID": "com.example.demo"}"#
        )

        let client = StubClientCapability()
        client.appsByBundleID["com.example.demo"] = makeApp(id: "app-1", bundleID: "com.example.demo")
        client.versionsByAppID["app-1"] = [makeVersion(id: "v1", versionString: "2.0.0")]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)

        #expect(viewModel.hasBinding == true)
        #expect(viewModel.binding?.bundleID == "com.example.demo")
        #expect(viewModel.app?.id == "app-1")
        #expect(viewModel.versionCount == 1)
        #expect(client.findAppCallCount == 1)
    }

    @Test("a bundle id with no matching app reports an error")
    func unmatchedBundleIDReportsError() async {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(
            projectPath: project.path,
            json: #"{"bundleID": "com.example.missing"}"#
        )

        let client = StubClientCapability()
        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(project.path)
        await waitUntilSettled(viewModel)

        #expect(viewModel.hasBinding == true)
        #expect(viewModel.app == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("switching projects clears the previous app and versions")
    func switchingProjectsClearsState() async {
        let first = makeProjectDirectory()
        let second = makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        writeAppConfiguration(projectPath: first.path, json: #"{"appID": "app-1"}"#)

        let client = StubClientCapability()
        client.appsByID["app-1"] = makeApp(id: "app-1", bundleID: "com.example.one")
        client.versionsByAppID["app-1"] = [makeVersion(id: "v1", versionString: "1.0.0")]

        let viewModel = ASCChatToolbarViewModel(clientCapability: client)
        viewModel.updateProjectPath(first.path)
        await waitUntilSettled(viewModel)
        #expect(viewModel.versionCount == 1)

        viewModel.updateProjectPath(second.path)
        await waitUntilSettled(viewModel)

        #expect(viewModel.app == nil)
        #expect(viewModel.versions.isEmpty)
        #expect(viewModel.hasBinding == false)
    }
}
