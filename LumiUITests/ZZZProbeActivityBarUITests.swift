import XCTest

/// 临时负向对照探针（验证后即删除）。
///
/// 目的：证明 `LumiActivityBarFreshInstallUITests` 的判据不是空洞通过。
/// 本探针**不带** `--lumi-ui-testing-isolated-storage`，因此使用用户真实数据目录；
/// 若该目录下已存在启用了第二个插件的记录（`plugin-enabled-overrides.plist`），
/// ActivityBar 应当出现，探针的 XCTAssertTrue 应当通过。
///
/// 反之若探针也「Chat 入口不存在」，说明隔离存储参数才是隐藏了 ActivityBar 的原因，
/// 正式测试的判据方向正确；若探针的 Chat 入口存在而正式测试说不存在，
/// 说明正式测试的定位方式有问题。
final class LumiActivityBarProbeUITests: XCTestCase {
    private var app: XCUIApplication!

    private enum ChatEntry {
        static let systemImageName = "bubble.left.and.bubble.right.fill"
        static let title = "Chat"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // 刻意不加 --lumi-ui-testing-isolated-storage：走用户真实数据目录。
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        // 等 App 真正退出：terminate() 是异步的，不等会让「上一个用例还在退出」
        // 漂移成「下一个用例偶发失败」。本类继承 XCTestCase，故内联实现。
        if app.state != .notRunning {
            app.terminate()
            let stopped = NSPredicate(
                format: "state == %d",
                XCUIApplication.State.notRunning.rawValue
            )
            _ = XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: stopped, object: app)],
                timeout: 10
            )
        }
        try super.tearDownWithError()
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 打印主窗口内所有 Button 的 AX label，供人工核对 ActivityBar 是否真的在渲染。
    func testProbeRealStorageActivityBar() throws {
        let root = element(identifier: "root.main")
        XCTAssertTrue(root.waitForExistence(timeout: 40), "主窗口未就绪")

        // 等一段时间，给插件 onReady 注册入口留出时间，避免「太早断言」。
        Thread.sleep(forTimeInterval: 12)

        let buttons = root.buttons.allElementsBoundByIndex
        let labels = buttons.map { "\($0.label)|exists=\($0.exists)|hittable=\($0.isHittable)" }
        print("PROBE_BUTTON_LABELS_BEGIN")
        for l in labels { print("PROBE_BUTTON \(l)") }
        print("PROBE_BUTTON_LABELS_END count=\(labels.count)")

        let chatEntry = root.buttons
            .matching(NSPredicate(format: "label == %@", ChatEntry.systemImageName))
            .firstMatch
        let chatTitle = root.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", ChatEntry.title))
            .firstMatch

        print("PROBE chatEntryExists=\(chatEntry.exists) chatTitleExists=\(chatTitle.exists)")
    }
}
