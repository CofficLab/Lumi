import FactoryCore
import KernelLumi
import SwiftUI
import XCTest

/// `OpenProjectHandler` 的外部打开路由测试。
///
/// 不经过完整 `startup()`（需要全部核心服务插件），只构造裸
/// `KernelLumi` 并通过 `PluginManager.initializePlugins` 注入记录型
/// 插件，验证「kernel 未就绪时排队、configure 后重放、无效路径丢弃」
/// 这一冷启动数据安全逻辑。
@MainActor
final class OpenProjectHandlerTests: XCTestCase {
    // MARK: - Test Helpers

    /// 记录 `openFile` 分发的最小插件实现。
    private final class FileRecordingPlugin: LumiPlugin {
        let id = "com.coffic.lumi.factory-core.test.open-file-recorder"
        let name = "OpenFileRecorder"
        let order = 200
        let policy: LumiPluginPolicy = .alwaysOn
        let category: LumiPluginCategory = .general
        let stage: LumiPluginStage = .stable
        let pluginDescription = ""

        nonisolated(unsafe) static var receivedURLs: [URL] = []

        func onBoot(kernel: KernelLumi) async throws {}
        func onReady(kernel: KernelLumi) async throws {}
        func openFile(kernel: KernelLumi, url: URL) -> Bool {
            Self.receivedURLs.append(url)
            return true
        }
        func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
        func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
        func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
        func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
        func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
        func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
        func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
        func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
        func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
        func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
        func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
        func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
        func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
        func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
        func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
        func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
        func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
        func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
        func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
        func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
        func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
        func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
        func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
        func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
        func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
        func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    }

    private var temporaryDirectory: URL!

    override func setUp() async throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-project-handler-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        FileRecordingPlugin.receivedURLs = []
        try await super.setUp()
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try await super.tearDown()
    }

    /// 裸内核：仅注册记录型插件，不执行完整启动自检。
    private func makeKernel() async throws -> KernelLumi {
        let kernel = KernelLumi()
        try await kernel.pluginManager.initializePlugins([FileRecordingPlugin()], kernel: kernel)
        return kernel
    }

    private func makeTemporaryFile(named name: String) throws -> String {
        let url = temporaryDirectory.appendingPathComponent(name)
        try "factory-core".data(using: .utf8)!.write(to: url)
        return url.path
    }

    // MARK: - Tests

    func testQueuedPathsAreReplayedAfterKernelConfigured() async throws {
        let path = try makeTemporaryFile(named: "queued.txt")

        // kernel 未就绪：请求进入待处理队列，不分发。
        OpenProjectHandler.shared.requestOpen(path: path)
        XCTAssertTrue(FileRecordingPlugin.receivedURLs.isEmpty)

        // configure 后重放队列，插件收到标准化后的路径。
        let kernel = try await makeKernel()
        OpenProjectHandler.shared.configure(kernel: kernel)
        XCTAssertEqual(FileRecordingPlugin.receivedURLs.map(\.path), [path])
    }

    func testNonExistentPathIsDroppedNotQueued() async throws {
        let missingPath = temporaryDirectory.appendingPathComponent("missing.txt").path

        OpenProjectHandler.shared.requestOpen(path: missingPath)
        let kernel = try await makeKernel()
        OpenProjectHandler.shared.configure(kernel: kernel)

        // 不存在的路径不应排队也不应重放。
        XCTAssertTrue(FileRecordingPlugin.receivedURLs.isEmpty)
    }

    func testPostConfigureRequestsDispatchImmediately() async throws {
        let path = try makeTemporaryFile(named: "direct.txt")
        let kernel = try await makeKernel()
        OpenProjectHandler.shared.configure(kernel: kernel)

        OpenProjectHandler.shared.requestOpen(path: path)
        XCTAssertEqual(FileRecordingPlugin.receivedURLs.map(\.path), [path])
    }

    func testEmptyPathIsRejected() async throws {
        OpenProjectHandler.shared.requestOpen(path: "")
        let kernel = try await makeKernel()
        OpenProjectHandler.shared.configure(kernel: kernel)
        XCTAssertTrue(FileRecordingPlugin.receivedURLs.isEmpty)
    }
}
