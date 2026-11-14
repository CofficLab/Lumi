import AppKit
import XCTest

/// 回归：外部「在 Lumi 中打开项目」第一次点击就必须切换当前项目。
///
/// 复现链路与 GitOK 完全一致：**外部进程**（GitOK / Finder）用
/// `NSWorkspace.open(_:withApplicationAt:)` 把一个已存在的文件夹交给
/// **正在运行的** Lumi，Launch Services 转成 `odoc` 事件送到
/// `LumiAppDelegate.application(_:open:)`。
///
/// 曾出现的症状：第一次点击被静默丢弃，工具栏仍显示上一个项目（或保持空），
/// 在同一个项目上再点一次才切换。根因是 `@Published` 在 `willSet` 阶段发布，
/// 消费方在 `.onReceive` 回调里直接比较属性拿到的是旧值，于是把真正的新请求
/// 误判成重复请求丢弃。见 `LumiApp.consumePendingOpenPath(_:kernel:)`。
///
/// 本用例用两个不同文件夹**依次**打开，且每个都只发一次事件：
/// 第二个文件夹就是用户「再点一次」的场景，但它必须以新请求的身份在
/// 首次事件里生效——这正是修复前后的分水岭。
final class LumiOpenExternalProjectUITests: LumiUITestCase {
    /// Debug 构建的 bundle id（见 `LumiApp/Config/Lumi-Debug.xcconfig`）。
    private static let debugBundleID = "com.coffic.lumi.debug"

    /// 工具栏项目控件的 `value` 是当前项目路径（不是显示名）。
    ///
    /// 用路径断言：项目名会随本地化、重名、改名变化，路径才是稳定判据。
    ///
    /// - Important: 不能按 `accessibilityIdentifier` 定位。工具栏宿主
    ///   （`LumiPluginRootView/WorkbenchRootHostView`）给整个标题栏设置了
    ///   `root.main`，子控件的 identifier 在 AX 树里被覆盖——实测标题栏上
    ///   所有按钮的 `AXIdentifier` 都是 `root.main`，只有 value 能区分它们。
    private func toolbarProjectControl(path: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "value == %@", path))
            .firstMatch
    }

    /// 本用例创建的临时目录，tearDown 统一清理。
    private var tempRoots: [URL] = []

    override func tearDownWithError() throws {
        tempRoots.forEach { try? FileManager.default.removeItem(at: $0) }
        tempRoots = []
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    func testFirstExternalOpenSwitchesCurrentProject() throws {
        // 隔离存储每次启动都是全新空目录：初始没有当前项目。
        // 注意空状态下项目工具栏项是**隐藏**的
        // （`NoConversationSelectedToolbarCoordinator` 会隐藏 `.project` 类别），
        // 所以这里不能断言「初始路径为空」——首个成功的外部打开会让控件出现，
        // 而事件被丢弃时它会一直不出现。两种状态的区分本身就是判据。
        launchLumi(extraArguments: ["--lumi-ui-testing-isolated-storage"])
        waitForMainWindow()

        let first = try makeFolder(named: "ExternalOpenFirst")
        sendExternalOpen(first)
        assertToolbarProjectEquals(first, context: "第一次外部打开项目")

        // 换一个项目再打开：对 Lumi 而言这是又一个新请求，
        // 必须在首次事件里生效，不能要求「再点一次」。
        let second = try makeFolder(named: "ExternalOpenSecond")
        sendExternalOpen(second)
        assertToolbarProjectEquals(second, context: "外部切换到第二个项目")
    }

    // MARK: - Helpers

    /// 在测试进程的临时目录里造一个真实文件夹。
    ///
    /// Lumi 打开外部路径前会校验目录存在（`KernelFactory.openExternalPath`），
    /// 不存在的路径会被直接拒绝，断言的失败点就跑到夹具上了。
    private func makeFolder(named name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiExternalOpen-\(UUID().uuidString)", isDirectory: true)
        let folder = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        tempRoots.append(root)
        return folder
    }

    /// 像 GitOK 一样把文件夹交给正在运行的 Lumi。
    ///
    /// - Note: 必须指向**运行中**实例的 bundle URL：Launch Services 对已注册的
    ///   运行实例做事件投递，而不是再起一个进程。`launchLumi` 已清掉残留实例，
    ///   所以这里拿到的就是被测进程。
    private func sendExternalOpen(_ folder: URL) {
        let target = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.debugBundleID)
            .first { !$0.isTerminated }
        guard let appURL = target?.bundleURL else {
            XCTFail("未找到正在运行的 Lumi 实例（\(Self.debugBundleID)），无法投递外部打开事件")
            return
        }

        let delivered = expectation(description: "Launch Services 受理外部打开事件")
        let configuration = NSWorkspace.OpenConfiguration()
        // 不抢前台：用例只关心项目是否切换，激活由 App 自己决定。
        configuration.activates = false
        NSWorkspace.shared.open([folder], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error {
                XCTFail("投递外部打开事件失败：\(error.localizedDescription)")
            }
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 30)
    }

    /// 等待工具栏出现指向期望路径的项目控件。
    ///
    /// 断言的超时给足 30s，但**不做重试投递**：只等一次事件的结果。
    /// 若这里等不到，说明首次事件确实没有被消费，而不是等得不够久。
    /// 控件只在存在项目时渲染（空状态隐藏 `.project` 类别），
    /// 所以「控件没出现」和「路径没切过去」在此都是同一个失败点。
    private func assertToolbarProjectEquals(_ folder: URL, context: String) {
        // 与 `KernelFactory.openExternalPath` 相同的规范化：测试临时目录可能
        // 位于符号链接路径下（如 `/var` → `/private/var`），两边的字符串必须可比。
        let expected = folder
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        let control = toolbarProjectControl(path: expected)
        XCTAssertTrue(
            control.waitForExistence(timeout: 30),
            """
            \(context)：工具栏当前项目没有切换过去。
            期望路径：\(expected)
            「第一次点击被丢弃、同一个项目再点一次才生效」正是本用例要防的回归。
            """
        )
    }
}
