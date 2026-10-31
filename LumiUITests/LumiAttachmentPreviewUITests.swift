import XCTest

/// 附件预览 ✕ 按钮的 UI 测试。
///
/// 单元测试（`AttachmentPreviewRemovalTests`）锁住了移除链路的**状态**：
/// ViewModel 的数组、Sender 的挂起池、`canSend` 判定。但它无法回答
/// 用户真正关心的问题：
///
/// **缩略图右上角那个 ✕，在真实界面上点得动吗？**
///
/// 这类问题只存在于真实渲染中，单测完全触及不到：
/// - 按钮的命中区域是否被 72×72 缩略图的边界裁掉；
/// - ✕ 用 `.offset(x: 6, y: -6)` 外移出缩略图后，父容器是否仍能命中它；
/// - 预览行嵌在横向 `ScrollView` 里，滚动手势会不会抢走点击。
///
/// 这正是 `LumiSendActionBarUITests` 为发送按钮建立的同一套论证范式。
///
/// ## 夹具
///
/// 启动参数 `--lumi-ui-testing-attachment-preview` 让插件注入 2 张图片 +
/// 2 个文件（见 `AttachmentPreviewUITestingSupport`）。不这么做是因为实测
/// XCUITest 无法可靠地把文件拖到 SwiftUI 的 drop destination 上。
///
/// ## 为什么按标识符定位
///
/// 与 `SendActionBarAccessibility` 同理：✕ 的 AX label 是本地化文案，
/// 随 `-AppleLanguages` 变化。本文件统一以英文启动，按 label 也能过，
/// 但那会让用例在非英文环境下静默失效——故一律按 identifier。
final class LumiAttachmentPreviewUITests: LumiUITestCase {
    private enum Identifiers {
        static let removeImageButton = "lumi.conversation-input.attachment.remove-image"
        static let removeFileButton = "lumi.conversation-input.attachment.remove-file"
    }

    /// 与 `AttachmentPreviewUITestingSupport` 保持一致。
    private enum Fixture {
        static let imageCount = 2
        static let fileCount = 2
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchLumi(extraArguments: [
            // 确定性 LLM 供应商 + 隔离存储。
            "--lumi-ui-testing",
            "--lumi-ui-testing-isolated-storage",
            // 注入确定性附件，避免依赖拖放手势。
            "--lumi-ui-testing-attachment-preview",
        ])
        waitForMainWindow()
    }

    // MARK: - 前提

    /// 夹具确实把预览渲染出来了。
    ///
    /// 后续所有用例都建立在这个前提上，因此单独用一条用例把它钉死——
    /// 否则夹具失效时，后续断言会以「点不到 ✕」的形式失败，
    /// 让人误判成按钮缺陷。
    ///
    /// 刻意不断言文件名：文件 chip 的文件名是 `Text`，宽度受限时会被
    /// SwiftUI 截断成 `ui-test-preview.…`，AX label 随之截断，全等匹配必然失败。
    /// 图片缩略图则完全没有可访问文本（曾因此让按文件名定位的写法落空），
    /// 它的标识只在 ✕ 按钮上——两者的可访问性形态不同，故只按 ✕ 计数判定。
    func testAttachmentPreviewIsRendered() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount),
            "夹具注入的图片缩略图数量不符（期望 \(Fixture.imageCount)）"
        )
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeFileButton, equals: Fixture.fileCount),
            "夹具注入的文件 chip 数量不符（期望 \(Fixture.fileCount)）"
        )
    }

    // MARK: - ✕ 的核心行为

    /// 点图片 ✕ 后该缩略图消失，另一张不受影响。
    ///
    /// 这是本次要回答的核心问题。用两张图而非一张是必要的：单图无法区分
    /// 「点击命中了正确的那个」与「碰巧删掉了唯一的那张」。
    func testClickingRemoveImageButtonRemovesOnlyThatThumbnail() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount),
            "图片缩略图未出现"
        )

        elements(identifier: Identifiers.removeImageButton).element(boundBy: 0).click()

        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount - 1),
            "点击图片 ✕ 后缩略图数量未减少"
        )
    }

    /// 依次点掉全部图片 ✕，预览里的图片区清空。
    ///
    /// 覆盖「✕ 被父容器裁剪后点不到」的失败模式：若第二个 ✕ 的命中区域
    /// 不可用，这条会在第二次点击处失败，而单张场景的用例仍会通过。
    func testClickingAllRemoveImageButtonsClearsImages() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount),
            "图片缩略图未出现"
        )

        // 每点一次都等数量减少，避免在 SwiftUI 还没重绘时点下一个。
        for expected in stride(from: Fixture.imageCount - 1, through: 0, by: -1) {
            let button = elements(identifier: Identifiers.removeImageButton).element(boundBy: 0)
            XCTAssertTrue(button.exists, "第 \(expected + 1) 次点击时找不到图片 ✕")
            button.click()
            XCTAssertTrue(
                waitForElementCount(identifier: Identifiers.removeImageButton, equals: expected),
                "点击第 \(expected + 1) 个图片 ✕ 后，剩余数量不是 \(expected)"
            )
        }
    }

    /// 点文件 chip 的 ✕ 后该 chip 消失，另一个文件不受影响。
    func testClickingRemoveFileButtonRemovesOnlyThatChip() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeFileButton, equals: Fixture.fileCount),
            "文件 chip 未出现"
        )

        elements(identifier: Identifiers.removeFileButton).element(boundBy: 0).click()

        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeFileButton, equals: Fixture.fileCount - 1),
            "点击文件 ✕ 后 chip 数量未减少"
        )
    }

    /// 图片 ✕ 与文件 ✕ 各自只作用于自己的类型。
    ///
    /// 覆盖两条链路交叉时的误删：`removeImageAttachment` 与
    /// `removeFileAttachment` 都按 UUID 移除，若某个实现误写成
    /// 「清空全部」，这条会失败。
    func testRemovingImageLeavesFileChipsUntouched() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount),
            "图片缩略图未出现"
        )
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeFileButton, equals: Fixture.fileCount),
            "文件 chip 未出现"
        )

        elements(identifier: Identifiers.removeImageButton).element(boundBy: 0).click()

        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount - 1),
            "图片 ✕ 点击后图片数量未减少"
        )
        // 文件 chip 必须纹丝不动。
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeFileButton, equals: Fixture.fileCount),
            "移除图片后文件 chip 数量发生变化"
        )
    }

    /// 附件全部移除后预览行整体消失。
    ///
    /// 覆盖 `AttachmentPreviewView` 的显示条件（两类附件皆空则整行不渲染）。
    /// 若该条件写错，预览会留下一行空白底色——用户看到的是
    /// 「输入框上方多了一条空条」。
    func testPreviewRowDisappearsAfterRemovingAllAttachments() throws {
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: Fixture.imageCount),
            "图片缩略图未出现"
        )

        // 依次点掉全部图片与文件，每一步都等重绘完成。
        for expected in stride(from: Fixture.imageCount - 1, through: 0, by: -1) {
            elements(identifier: Identifiers.removeImageButton).element(boundBy: 0).click()
            XCTAssertTrue(
                waitForElementCount(identifier: Identifiers.removeImageButton, equals: expected),
                "图片 ✕ 第 \(expected + 1) 次点击后数量不对"
            )
        }
        for expected in stride(from: Fixture.fileCount - 1, through: 0, by: -1) {
            elements(identifier: Identifiers.removeFileButton).element(boundBy: 0).click()
            XCTAssertTrue(
                waitForElementCount(identifier: Identifiers.removeFileButton, equals: expected),
                "文件 ✕ 第 \(expected + 1) 次点击后数量不对"
            )
        }

        // 两类 ✕ 全部消失 → 预览行已空。
        XCTAssertTrue(
            waitForElementCount(identifier: Identifiers.removeImageButton, equals: 0),
            "附件全部移除后预览行没有消失"
        )
    }

    // MARK: - Helpers

    /// 按标识符取全部匹配元素。
    ///
    /// 刻意不复用 `LumiUITestCase.element(identifier:)`：那个返回
    /// `firstMatch`，无法断言「数量减少了」。预览的 ✕ 有多个，必须按数量判定。
    private func elements(identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    /// 轮询等待某标识符的元素数量达到期望值。
    ///
    /// 刻意**不使用** `NSPredicate(format: "count == %d")` 配
    /// `XCTNSPredicateExpectation`：实测该组合对 `XCUIElementQuery` 的
    /// `count` 求值不可靠，会在元素确实减少后仍然超时——曾把一条
    /// 「点击生效」的用例判成失败。改为在主线程外自己重新查询并轮询。
    private func waitForElementCount(
        identifier: String,
        equals expected: Int,
        timeout: TimeInterval = 10
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements(identifier: identifier).count == expected { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        // 最后再报一次实际值，便于定位。
        return elements(identifier: identifier).count == expected
    }
}
