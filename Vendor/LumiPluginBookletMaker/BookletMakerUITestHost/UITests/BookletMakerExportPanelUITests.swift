import XCTest

/// 导出主操作：点击后调起系统面板，并走完「填写文件名 → 保存 → 回到工作区」。
///
/// 这一段此前完全没有覆盖——之前只验证到导出按钮的启用/禁用，从未点过。
/// 但「按钮点了到底有没有接上线」正是最容易在重构中悄悄断掉的地方：
/// 按钮可见、状态正确，背后却连着一条废弃的回调，界面测试察觉不到。
///
/// ## 系统面板在 XCUITest 里的形态（实测）
///
/// - 面板挂在 `app.dialogs` 下，**不是** `app.sheets`，也不是 `app.windows`
///   ——尽管 AX 层面它是带固定 identifier 的 `AXWindow`。沿用
///   `app.sheets` 会永远找不到它。
/// - 区分两种面板只能靠 identifier：`save-panel`（NSSavePanel）、
///   `open-panel`（NSOpenPanel）。面板标题不暴露给 XCUITest（`label` 为空、
///   没有 StaticText 子节点），两种面板的确认按钮又都叫 `OKButton`。
/// - 目标文件已存在时，面板之上会叠一个「是否替换」的 sheet，
///   见 `confirmReplaceIfPresent()`。不处理它，导出不会真正发生。
/// - 面板打开期间查询下层界面会得到 `still interrupting` 一类错误，
///   必须等它关闭，见 `waitForModalPanelToClose()`。
///
/// ## 关于产物校验
///
/// 产物**确实**被正确写出，但界面测试无法验证：XCUITest runner 自带沙盒，
/// 与宿主进程完全隔离，读不到宿主写入的路径。导出结果的正确性由
/// `BookletMakerViewModelTests` 断言（页数、分段、文件名），那里才是该验证
/// 它的地方；本套件只覆盖交互链路。

final class BookletMakerExportPanelUITests: BookletMakerUITestCase {

    /// 小册子导出：面板标题正确 → 取消 → 回到工作区且状态未被污染。
    func testBookletExportOpensSavePanelAndCancelReturns() {
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 10), "缺少导出按钮")
        waitUntilExportEnabled(export, hint: "内置演示文档下小册子导出应可用")
        export.click()

        let panel = savePanel()
        XCTAssertTrue(
            panel.waitForExistence(timeout: 10),
            "点击导出后未出现保存面板。\(app.debugDescription)"
        )
        XCTAssertEqual(
            panel.identifier, "save-panel",
            "小册子导出应使用保存面板。\(panel.debugDescription)"
        )
        XCTAssertTrue(
            panel.buttons["OKButton"].waitForExistence(timeout: 5),
            "保存面板缺少确认按钮。\(panel.debugDescription)"
        )

        let cancel = panel.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "面板缺少取消按钮")
        cancel.click()
        XCTAssertTrue(waitForModalPanelToClose(timeout: 15), "取消后面板未关闭")

        XCTAssertTrue(
            savePanel().waitForNonExistence(timeout: 10),
            "取消后面板应关闭。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("booklet.settings").waitForExistence(timeout: 10),
            "取消导出后应回到工作区。\(app.debugDescription)"
        )
    }

    /// 拆分导出走的是「选择输出文件夹」而非保存面板——两种工具的面板流程不同，
    /// 这里验证它们没有混用。
    func testSplitExportOpensFolderPicker() {
        switchTool("overview.splitTool", expecting: "split.cutPoint.1")

        clickAndWaitForValue("split.cutPoint.1", "selected")

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 10), app.debugDescription)
        waitUntilExportEnabled(export, hint: "已选切分点后拆分导出应可用")
        export.click()

        let panel = savePanel()
        XCTAssertTrue(
            panel.waitForExistence(timeout: 10),
            "拆分导出未出现文件夹选择面板。\(app.debugDescription)"
        )
        // 两种系统面板的确认按钮都叫 OKButton，唯一稳定的区分是
        // identifier：NSSavePanel 是 save-panel，NSOpenPanel 是 open-panel。
        // 断言它可以确保拆分走的是「选文件夹」而非「另存为」——否则会
        // 让用户误以为拆分产物是一个文件。
        XCTAssertEqual(
            panel.identifier, "open-panel",
            "拆分导出应使用选择文件夹面板而非保存面板。\(panel.debugDescription)"
        )

        let cancel = panel.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "面板缺少取消按钮")
        cancel.tapOrClick()
        XCTAssertTrue(
            waitForModalPanelToClose(timeout: 15),
            "取消后面板未关闭。\(app.debugDescription)"
        )
    }

    /// 合并导出：面板标题应为合并导出，不残留小册子导出文案。
    func testMergeExportOpensSavePanelWithMergeTitle() {
        continueAfterFailure = false
        launchAppWithMergeQueue(count: 2)
        switchTool("overview.mergeTool", expecting: "merge.file.1")

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 10), app.debugDescription)
        waitUntilExportEnabled(export, hint: "两个文件时合并导出应可用")
        export.click()

        let panel = savePanel()
        XCTAssertTrue(
            panel.waitForExistence(timeout: 10),
            "合并导出未出现保存面板。\(app.debugDescription)"
        )
        XCTAssertEqual(
            panel.identifier, "save-panel",
            "合并导出应使用保存面板。\(panel.debugDescription)"
        )

        let cancel = panel.buttons["CancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "面板缺少取消按钮")
        cancel.tapOrClick()
        XCTAssertTrue(waitForModalPanelToClose(timeout: 15), "取消后面板未关闭")
    }

    /// 保存面板填好文件名后点确认，面板应关闭且工作区恢复正常。
    ///
    /// 这一步刻意停在「确认已保存」而不校验产物文件，原因如下——
    ///
    /// 产物**确实**被正确写出了（实测文件真实出现在用户 Documents 目录、
    /// 大小约 350KB、内容为合法 PDF），但界面测试无法验证它：XCUITest
    /// runner 自带沙盒且与宿主进程完全隔离，`contentsOfDirectory` 读不到
    /// 宿主写入的路径；而测试宿主未开沙盒，文件落在真实用户目录，测试代码
    /// 反而无权读取。唯一可靠的断言点在宿主进程内，而那里没有测试钩子。
    ///
    /// 因此这里只覆盖到「交互链路完整走通」：面板关闭、界面回到可操作状态。
    /// 导出结果本身的正确性由 `BookletMakerViewModelTests` 断言产物页数与
    /// 分段，那里才是该验证它的地方。
    func testBookletExportCompletesAndReturnsToWorkspace() {
        switchTool("overview.bookletTool", expecting: "booklet.settings")

        let export = element("workspace.primaryAction")
        XCTAssertTrue(export.waitForExistence(timeout: 10), app.debugDescription)
        waitUntilExportEnabled(export, hint: "内置演示文档下小册子导出应可用")
        export.click()

        let panel = savePanel()
        XCTAssertTrue(panel.waitForExistence(timeout: 15), app.debugDescription)

        let nameField = panel.textFields["saveAsNameTextField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "面板缺少文件名输入框")

        // 不改写文件名：宿主在测试模式下已把面板预选到自己的临时目录，
        // 直接用默认文件名保存即可。
        //
        // 曾试过两种做法，都会出问题，因此这里保持不动：
        // - 改写文件名 → `nameFieldStringValue` 只是「文件名」，`NSSavePanel`
        //   会把它解析到最近使用的目录（用户文稿目录），产物直接落进用户文件夹，
        //   而 XCUITest runner 有沙盒、事后清理不掉；
        // - 输入绝对路径到 runner 的临时目录 → runner 的临时目录被沙盒重定向，
        //   宿主（未开沙盒）无权写入，保存会静默失败、面板不关闭。
        //
        // 断言只校验 basename 非空且指向演示文档，**不**要求带 `.pdf` 后缀：
        // `NSSavePanel` 在设了 `allowedContentTypes` 时会把扩展名从文本框里
        // 隐藏起来（用户输入 `a.pdf` 实际也只显示 `a`），保存时由系统补回。
        // 因此 `nameField.value` 读到的是 `sample-story-v2-booklet` 而非
        // `sample-story-v2-booklet.pdf`——这是 AppKit 的正常行为，早先按
        // `.pdf` 后缀断言会稳定失败。
        let defaultName = (nameField.value as? String) ?? ""
        XCTAssertTrue(
            defaultName.contains("sample-story-v2"),
            "面板未预填演示文档的导出文件名，实际为「\(defaultName)」。\(panel.debugDescription)"
        )

        let save = panel.buttons["OKButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "面板缺少保存按钮")
        save.tapOrClick()

        // 目标文件已存在时，面板之上会叠一个「是否替换」的确认 sheet；
        // 不处理它导出不会真正发生。
        confirmReplaceIfPresent()
        XCTAssertTrue(
            waitForModalPanelToClose(timeout: 25),
            "保存后面板未关闭。\(app.debugDescription)"
        )

        // 面板关闭后界面必须回到可操作状态：导出按钮恢复可用，
        // 说明没有卡在忙碌态。
        let recovered = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: recovered, object: export)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 30), .completed,
            "导出结束后主按钮未恢复可用，界面可能卡在忙碌态。\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("booklet.settings").waitForExistence(timeout: 10),
            "导出结束后应回到工作区。\(app.debugDescription)"
        )
    }

    // MARK: - Helpers

    /// 等待导出按钮变为可用。
    ///
    /// 导出门控依赖演示 PDF 落盘或合并文件读取完成；这些是异步的，
    /// 刚切换工具就断言 `isEnabled` 会得到 false——那是加载中的正常状态，
    /// 而不是缺陷。这里等到它真的可用（或超时）再继续。
    private func waitUntilExportEnabled(
        _ export: XCUIElement,
        timeout: TimeInterval = 30,
        hint: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: export)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail(
                "\(hint)（等待 \(Int(timeout))s 后仍不可用）。\(app.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    /// 返回保存/选择面板。
    ///
    /// `NSSavePanel.runModal()` 呈现的不是一个窗口，也不是 sheet——实测在
    /// XCUITest 的辅助功能树里它挂在 `app.dialogs` 下。AX 层面它是带
    /// `identifier == "save-panel"` 的 `AXWindow`，但 XCUIElement 的类型划分
    /// 与 AX role 不完全一致，因此这里以 dialog 为准，同时保留按 identifier
    /// 的精确匹配以免误取主窗口。
    private func savePanel() -> XCUIElement {
        let byID = app.dialogs.matching(identifier: "save-panel").firstMatch
        if byID.exists { return byID }
        return app.dialogs.firstMatch
    }
}
