import XCTest
import AppKit

/// 「设置 → 供应商 → 添加供应商」端到端 UI 测试。
///
/// ## 为什么必须驱动真实 App
///
/// 「添加供应商」是一条跨插件的长链路：
/// 设置页按钮 → 弹出编辑器 → 填表 → `UserDefinedCloudProviderStore.upsert`
/// → 落盘 + 注册进运行时管理器 → 发布者通知设置页刷新列表。
/// 任何一环静默失效，界面表现都是同一个：**列表里没有新供应商**。
/// 包内单元测试能覆盖解析、校验与落盘，却覆盖不到
/// 「按钮能不能点到」「表单能不能填进去」「列表会不会刷新」这三段——
/// 它们只存在于真实渲染与真实交互里。
///
/// ## 确定性来源
///
/// `--lumi-ui-testing-isolated-storage` 把数据根目录重定向到临时目录下的
/// 全新 UUID 子目录（见 `KernelFactory.uiTestingDataRootDirectory()`），
/// 等价于全新安装：没有历史自定义供应商，每个用例互不污染。
///
/// ## 定位方式
///
/// 按**无障碍标识符**定位，而不是界面文案。
/// 设置页里的「添加供应商」「保存」等是插件内硬编码的中文字面量，
/// 不走 `String(localized:)`，不随 `-AppleLanguages` 变化；
/// 而「Providers」这类条目走的是插件资源包的字符串目录，会随语言变。
/// 混用两套判据会让用例在换语言时集体失效。
final class LumiCloudProviderAddUITests: LumiUITestCase {
    /// 无障碍标识符（复述 `ProviderSettingsAccessibility`）。
    ///
    /// UI 测试独立 target，不能 import 插件模块，因此在此复述常量。
    /// 改动必须与 `Packages/PluginLLMProviderSettings/.../ProviderSettingsAccessibility.swift` 同步。
    private enum Identifiers {
        static let addProvider = "lumi.provider-settings.add-provider"
        static let searchField = "lumi.provider-settings.search"
        static let providerCount = "lumi.provider-settings.provider-count"
        static let scopeSwitcher = "lumi.provider-settings.scope-switcher"
        static let nameField = "lumi.provider-settings.custom-provider.name"
        static let baseURLField = "lumi.provider-settings.custom-provider.base-url"
        static let modelsField = "lumi.provider-settings.custom-provider.models"
        static let saveButton = "lumi.provider-settings.custom-provider.save"
        static let cancelButton = "lumi.provider-settings.custom-provider.cancel"
    }

    /// 输入框占位符（插件内硬编码的稳定字面量，用作标识符定位的兜底）。
    private enum Placeholders {
        static let name = "供应商名称"
        static let baseURL = "API Endpoint URL"
    }

    /// 供应商计数标签的固定后缀（插件内硬编码中文，不随语言变化）。
    private static let cloudProviderCountSuffix = "个云端供应商"

    /// 唯一的供应商名称，避免与内置供应商重名。
    private static let providerName = "UI 测试网关"
    /// 等待 UI 元素的最长时限。
    ///
    /// - Important: Lumi 启动时要装配 240+ 个本地包，界面就绪远慢于普通 App。
    ///   这里统一放宽到 40s，避免把「App 还没起来」误判成「功能坏了」。
    private static let elementTimeout: TimeInterval = 40

    override func setUpWithError() throws {
        continueAfterFailure = false
        registerSystemDialogMonitor()
        launchLumi(extraArguments: [
            // 隔离存储：等价全新安装，避免历史自定义供应商干扰计数断言。
            "--lumi-ui-testing-isolated-storage",
        ])
        // 基类在此等待主窗口并关掉新手引导。
        waitForMainWindow()
    }

    override func tearDownWithError() throws {
        terminateAppAndWait()
        try super.tearDownWithError()
    }

    /// 注册系统弹窗中断监控。
    ///
    /// ## 为什么必须有它
    ///
    /// 打开「云端供应商」页会渲染供应商详情，其中 `loadAPIKey()` 会读钥匙串。
    /// Debug 构建的签名与钥匙串里 `com.coffic.lumi.apikey` 条目的 ACL 不匹配，
    /// macOS 会弹出「警告」授权对话框（宿主进程 `com.apple.coreservices.uiagent`）。
    ///
    /// 这个对话框是**模态系统弹窗**：它一出现，Lumi 进程就进入 Disabled 状态，
    /// XCUITest 后续所有点击都被它拦走，表现为「设置窗口没有出现」这类
    /// 与真实原因完全无关的失败。XCUITest 内置的中断监控处理不了钥匙串弹窗，
    /// 只能自己关掉它。
    ///
    /// - Note: 中断监控只在「有交互被阻塞」时才会被调用，
    ///   因此它不改变正常路径的行为，只是把被弹窗打断的交互救回来。
    private func registerSystemDialogMonitor() {
        addUIInterruptionMonitor(withDescription: "系统授权弹窗") { alert in
            // 只点「允许」类按钮，绝不点「拒绝 / 取消 / 帮助」——
            // 点错会让钥匙串读取失败，把环境问题变成一个更难查的功能问题。
            let allowLabels = ["始终允许", "允许", "Always Allow", "Allow", "OK", "好"]
            let denyLabels = ["拒绝", "取消", "帮助", "Deny", "Cancel", "Help"]
            let buttons = alert.buttons.allElementsBoundByIndex
            for label in allowLabels {
                for button in buttons where button.label == label {
                    button.click()
                    return true
                }
            }
            // 没有可识别的「允许」文案时，退而求其次点最后一个按钮
            //（macOS 系统弹窗的默认按钮通常是允许）。
            let candidate = buttons.last { button in
                !denyLabels.contains(button.label)
            }
            if let candidate {
                candidate.click()
                return true
            }
            return false
        }
    }

    // MARK: - 场景

    /// 填完表单保存后，新供应商出现在云端供应商列表，详情里能看到模型。
    func testAddProviderCreatesCloudProviderInList() throws {
        let settingsWindow = openCloudProvidersPage()
        let countBefore = cloudProviderCount()

        // 打开「添加供应商」编辑器。
        let addButton = button(identifier: Identifiers.addProvider)
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.elementTimeout), "云端供应商页缺少「添加供应商」按钮")
        addButton.click()
        XCTAssertTrue(waitForEditor(timeout: Self.elementTimeout), "「添加云端供应商」编辑器没有出现")

        // 填表。
        fill(
            name: Self.providerName,
            baseURL: "https://llm.example.com/v1",
            models: "ui-test-model-a\nui-test-model-b"
        )

        // 保存。
        let save = button(identifier: Identifiers.saveButton)
        XCTAssertTrue(save.isEnabled, "填完表单后保存按钮仍不可用")
        save.click()

        // 保存成功后编辑器关闭。
        XCTAssertTrue(
            waitForNonExistence(save, timeout: Self.elementTimeout),
            "保存后「添加云端供应商」编辑器没有关闭"
        )

        // 列表计数 +1。
        let countAfter = cloudProviderCount()
        XCTAssertEqual(
            countAfter,
            countBefore + 1,
            "保存后云端供应商计数没有 +1（保存前 \(countBefore)，保存后 \(countAfter)）"
        )

        // 侧边栏出现新供应商（供应商行是按钮）。
        //
        // - Important: 必须先用搜索把列表过滤到只剩目标供应商。
        //   侧边栏是 `LazyVStack`，新增的供应商排在列表末尾；
        //   末尾行在视口外时不会被物化，AX 树里根本不存在这个元素。
        let search = searchField(in: settingsWindow)
        XCTAssertTrue(search.waitForExistence(timeout: Self.elementTimeout), "供应商侧边栏缺少搜索框")
        paste(Self.providerName, into: search)

        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", Self.providerName)
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: Self.elementTimeout), "供应商列表里没有出现新增的「\(Self.providerName)」")

        // 选中它，详情里能看到保存的模型。
        row.click()
        XCTAssertTrue(
            element(containingLabel: "ui-test-model-a").waitForExistence(timeout: Self.elementTimeout),
            "新增供应商的详情里没有出现模型 ui-test-model-a"
        )
        XCTAssertTrue(
            element(containingLabel: "ui-test-model-b").waitForExistence(timeout: Self.elementTimeout),
            "新增供应商的详情里没有出现模型 ui-test-model-b"
        )
    }

    /// Base URL 非法时保存失败，错误提示可见，编辑器不关闭，供应商不被创建。
    func testAddProviderRejectsInvalidBaseURL() throws {
        _ = openCloudProvidersPage()
        let countBefore = cloudProviderCount()

        let addButton = button(identifier: Identifiers.addProvider)
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.elementTimeout), "云端供应商页缺少「添加供应商」按钮")
        addButton.click()
        XCTAssertTrue(waitForEditor(timeout: Self.elementTimeout), "「添加云端供应商」编辑器没有出现")

        fill(name: "非法地址网关", baseURL: "not-a-url", models: "ui-test-model-a")

        let save = button(identifier: Identifiers.saveButton)
        save.click()

        // 错误提示出现。
        XCTAssertTrue(
            element(containingLabel: "请输入有效的 HTTP/HTTPS API 地址。").waitForExistence(timeout: Self.elementTimeout),
            "Base URL 非法时没有出现错误提示"
        )
        // 编辑器保持打开（保存失败）。
        XCTAssertTrue(
            button(identifier: Identifiers.saveButton).exists,
            "Base URL 非法时编辑器被关闭了，保存失败没有反馈"
        )
        // 供应商没有被创建。
        XCTAssertEqual(
            cloudProviderCount(),
            countBefore,
            "保存失败后云端供应商计数发生了变化"
        )
    }

    /// 名称为空时保存按钮不可用；填入名称后恢复可用。
    func testSaveButtonIsDisabledUntilNameIsEntered() throws {
        _ = openCloudProvidersPage()

        let addButton = button(identifier: Identifiers.addProvider)
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.elementTimeout), "云端供应商页缺少「添加供应商」按钮")
        addButton.click()
        XCTAssertTrue(waitForEditor(timeout: Self.elementTimeout), "「添加云端供应商」编辑器没有出现")

        let save = button(identifier: Identifiers.saveButton)
        XCTAssertFalse(save.isEnabled, "名称为空时保存按钮应当不可用")

        // 填入名称。
        let nameField = textField(identifier: Identifiers.nameField, placeholder: Placeholders.name)
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少供应商名称输入框")
        paste("有名称的网关", into: nameField)

        // 等待按钮变为可用——「状态层已收到文本」的可观测证据。
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabled], timeout: 10),
            .completed,
            "填入名称后保存按钮仍未启用"
        )
    }

    /// 取消编辑不创建任何供应商。
    func testCancelAddProviderDoesNotCreateProvider() throws {
        _ = openCloudProvidersPage()
        let countBefore = cloudProviderCount()

        let addButton = button(identifier: Identifiers.addProvider)
        XCTAssertTrue(addButton.waitForExistence(timeout: Self.elementTimeout), "云端供应商页缺少「添加供应商」按钮")
        addButton.click()
        XCTAssertTrue(waitForEditor(timeout: Self.elementTimeout), "「添加云端供应商」编辑器没有出现")

        let nameField = textField(identifier: Identifiers.nameField, placeholder: Placeholders.name)
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少供应商名称输入框")
        paste("会被取消的网关", into: nameField)

        let cancel = button(identifier: Identifiers.cancelButton)
        XCTAssertTrue(cancel.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少取消按钮")
        cancel.click()

        XCTAssertTrue(
            waitForNonExistence(button(identifier: Identifiers.saveButton), timeout: Self.elementTimeout),
            "取消后「添加云端供应商」编辑器没有关闭"
        )
        XCTAssertEqual(
            cloudProviderCount(),
            countBefore,
            "取消后云端供应商计数发生了变化"
        )
    }

    /// 云端 / 本地合并成一个页面后，头部行右上角的分段控件能切换范围：
    /// 切到本地后，「添加供应商」（云端专属）消失，列表与表头换成本地供应商。
    func testScopeSwitcherSwitchesToLocalProviders() throws {
        _ = openCloudProvidersPage()

        // 分段控件在（头部行最右侧）。
        XCTAssertTrue(
            element(identifier: Identifiers.scopeSwitcher).waitForExistence(timeout: Self.elementTimeout),
            "供应商页缺少「云端 / 本地」分段控件"
        )

        // 切到本地。
        let localSegment = app.buttons.matching(
            NSPredicate(format: "label == %@", "本地")
        ).firstMatch
        XCTAssertTrue(
            localSegment.waitForExistence(timeout: Self.elementTimeout),
            "分段控件缺少「本地」页签"
        )
        localSegment.click()

        // 「添加供应商」是云端专属：切到本地后它必须消失。
        XCTAssertTrue(
            waitForNonExistence(button(identifier: Identifiers.addProvider), timeout: Self.elementTimeout),
            "切到本地范围后「添加供应商」按钮仍然存在"
        )

        // 表头计数也换成本地供应商。
        XCTAssertTrue(
            element(containingLabel: "个本地供应商").waitForExistence(timeout: Self.elementTimeout),
            "切到本地范围后表头没有换成「N 个本地供应商」"
        )
    }

    // MARK: - Helpers

    /// 打开设置窗口并切到「供应商」页（云端 / 本地合并后的入口），返回设置窗口。
    @discardableResult
    private func openCloudProvidersPage() -> XCUIElement {
        let gear = app.buttons["Gear Shape"]
        XCTAssertTrue(
            gear.waitForExistence(timeout: Self.elementTimeout),
            "工具栏缺少设置按钮"
        )

        let settingsWindow = app.windows.matching(identifier: "lumi.settings").firstMatch
        // 点一次不够就再点一次：第一次点击可能正好被系统弹窗吞掉，
        // 此时设置窗口不会出现，但工具栏按钮依然可点。
        if !settingsWindow.waitForExistence(timeout: 8) {
            gear.click()
        }
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: Self.elementTimeout),
            "设置窗口没有出现"
        )

        // 「Providers」走的是插件资源包的字符串目录，英文环境下渲染为英文。
        // 云端与本地合并成了一个条目，页内用右上角的分段控件切换范围；
        // 默认停在云端，所以「添加供应商」按钮直接可见。
        let entry = settingsWindow.buttons.matching(
            NSPredicate(format: "label == %@", "Providers")
        ).firstMatch
        XCTAssertTrue(
            entry.waitForExistence(timeout: Self.elementTimeout),
            "设置侧边栏缺少 Providers 条目"
        )
        entry.click()

        // 页面是否就绪，用「添加供应商」按钮判定——它带无障碍标识符，
        // 比按中文文案匹配表头更可靠。
        XCTAssertTrue(
            button(identifier: Identifiers.addProvider).waitForExistence(timeout: Self.elementTimeout),
            "供应商页没有渲染出来"
        )
        return settingsWindow
    }

    /// 定位侧边栏的供应商搜索框。
    ///
    /// 优先按无障碍标识符；标识符没落到 `AppSearchBar` 内部的 `TextField` 上时
    /// （SwiftUI 对「容器 → 子控件」的标识符传播不保证），
    /// 退回到占位符匹配。
    ///
    /// - Important: 标识符查询必须**按元素类型限定**。
    ///   `AppSearchBar` 的放大镜图标和它的 `TextField` 拿到的是**同一个**标识符
    ///   （实测两者都是 `lumi.provider-settings.search`），
    ///   不限定类型的话 `firstMatch` 可能抓到那个 `Image`——点它不会有任何反应。
    ///
    /// - Note: 两种占位符文案都列上。
    ///   「搜索供应商」在插件自己的字符串目录里登记过英文译文（`Search providers`），
    ///   而占位符是 `LocalizedStringKey`，最终渲染成哪一份取决于运行时的语言环境。
    ///   只认一种语言，就会在换语言后静默地匹配不到搜索框。
    ///
    /// - Important: 先在设置窗口内找，再退回全 App 范围。
    ///   模型选择器里也有一个占位符同为「Search providers」的搜索框，
    ///   全局取 `firstMatch` 有可能抓到它——而它不在设置窗口里。
    private func searchField(in window: XCUIElement) -> XCUIElement {
        let byIdentifier = app.textFields.matching(identifier: Identifiers.searchField).firstMatch
        if byIdentifier.exists { return byIdentifier }

        let predicate = NSPredicate(
            format: "placeholderValue IN %@",
            ["搜索供应商", "Search providers"]
        )
        let scoped = window.textFields.matching(predicate).firstMatch
        if scoped.exists { return scoped }
        return app.textFields.matching(predicate).firstMatch
    }

    /// 按标识符定位按钮。
    ///
    /// 限定元素类型是必需的：同一个标识符可能同时落在多个元素上
    /// （SwiftUI 会把它继承给容器里的图片等装饰性子元素）。
    private func button(identifier: String) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    /// 读取当前云端供应商数量。
    ///
    /// ## 文字在 `value` 里，不在 `label` 里
    ///
    /// SwiftUI 的 `Text` 暴露成 `StaticText` 时，文字放在 **`value`** 上，
    /// `label` 是空的。只按 `label` 匹配会一条都查不到——这是本用例最初失败的原因。
    ///
    /// ## 为什么用「数字紧挨着后缀」的正则
    ///
    /// 兜底扫描可能命中一个把整个表头都拼进去的容器元素，它的文字里
    /// 混着别的数字（「10 个模型」等）。用「数字 + 后缀」的整体匹配，
    /// 只认真正属于这个计数的那一段，容器里别处的数字一律不认。
    private func cloudProviderCount() -> Int {
        let suffix = Self.cloudProviderCountSuffix

        // 1) 标识符优先。
        let byIdentifier = app.staticTexts.matching(identifier: Identifiers.providerCount).firstMatch
        if byIdentifier.waitForExistence(timeout: 5),
           let count = Self.parseCount(Self.textContent(of: byIdentifier)) {
            return count
        }

        // 2) 兜底：静态文本，再不限类型。
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", suffix, suffix
        )
        let asStaticText = app.staticTexts.matching(predicate).firstMatch
        if asStaticText.exists, let count = Self.parseCount(Self.textContent(of: asStaticText)) {
            return count
        }
        let anyElement = app.descendants(matching: .any).matching(predicate).firstMatch
        if anyElement.exists, let count = Self.parseCount(Self.textContent(of: anyElement)) {
            return count
        }

        // 找不到就把整棵 AX 树打出来，否则只能看到一个没有上下文的失败。
        print("=== AX TREE (cloud provider count not found) ===\n\(app.debugDescription)")
        XCTFail("云端供应商计数标签没有出现")
        return 0
    }

    /// 元素的全部文字：SwiftUI 把 `Text` 的文字放在 `value` 上，
    /// 而 `Button` 的文字放在 `label` 上，两个都要看。
    private static func textContent(of element: XCUIElement) -> String {
        "\(element.label) \(element.value ?? "")"
    }

    /// 从「N 个云端供应商」这类文案里解析出 N。
    ///
    /// 只认**紧挨着后缀**的那段数字，容器拼接出来的其它数字一律忽略。
    private static func parseCount(_ content: String) -> Int? {
        guard let match = content.firstMatch(of: /(\d+)\s*个云端供应商/),
              let count = Int(match.1) else { return nil }
        return count
    }

    /// 等待编辑器出现。
    ///
    /// 判据用「保存按钮」：它是真的 `Button`，标识符落在 AX 元素上。
    ///
    /// - Important: 曾经把判据放在编辑器根容器上，那是错的——
    ///   SwiftUI 会把容器的标识符继承给所有直接子元素（标题、取消、保存……），
    ///   反而把「保存」按钮自己的标识符盖掉了。根容器因此不再挂任何标识符。
    private func waitForEditor(timeout: TimeInterval) -> Bool {
        button(identifier: Identifiers.saveButton).waitForExistence(timeout: timeout)
    }

    /// 定位文本输入框。
    ///
    /// 优先按无障碍标识符；标识符没落到 `AppInputField` 内部的 `TextField` 上时
    /// （SwiftUI 对「容器 → 子控件」的标识符传播不保证），
    /// 退回到占位符匹配——占位符是插件内硬编码的稳定字面量，且彼此不重名。
    ///
    /// 这里只影响**定位方式**，断言强度不变。
    private func textField(identifier: String, placeholder: String) -> XCUIElement {
        let byIdentifier = app.textFields.matching(identifier: identifier).firstMatch
        if byIdentifier.exists { return byIdentifier }
        return app.textFields.matching(
            NSPredicate(format: "placeholderValue == %@", placeholder)
        ).firstMatch
    }

    /// 定位多行文本输入框（模型 ID）。
    private func textView(identifier: String) -> XCUIElement {
        let byIdentifier = app.textViews.matching(identifier: identifier).firstMatch
        if byIdentifier.exists { return byIdentifier }
        return app.textViews.firstMatch
    }

    /// 填写表单。
    ///
    /// - Note: 文本一律走剪贴板粘贴（基类 `paste`），不用 `typeText`。
    ///   `typeText` 逐字符派发合成按键，会进入宿主输入法组合态并吞掉尾部字符，
    ///   详见 `LumiUITestCase` 里的实测对照表。
    private func fill(name: String, baseURL: String, models: String) {
        let nameField = textField(identifier: Identifiers.nameField, placeholder: Placeholders.name)
        XCTAssertTrue(nameField.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少供应商名称输入框")
        paste(name, into: nameField)

        let baseURLField = textField(identifier: Identifiers.baseURLField, placeholder: Placeholders.baseURL)
        XCTAssertTrue(baseURLField.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少 API Endpoint URL 输入框")
        paste(baseURL, into: baseURLField)

        let modelsField = textView(identifier: Identifiers.modelsField)
        XCTAssertTrue(modelsField.waitForExistence(timeout: Self.elementTimeout), "编辑器缺少模型 ID 输入框")
        // 多行输入框在滚动区底部，可能需要先滚出来。
        if !modelsField.isHittable {
            let scrollView = app.scrollViews.firstMatch
            for _ in 0..<4 {
                scrollView.swipeUp()
                if modelsField.isHittable { break }
            }
        }
        paste(models, into: modelsField)
    }
}
