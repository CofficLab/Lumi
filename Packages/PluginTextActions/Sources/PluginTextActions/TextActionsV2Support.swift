import AppKit
import ApplicationServices
import LumiUI
import ProviderLLMManager
import SwiftUI

enum TextActionsSettings {
    /// 配置落盘在插件专属目录（Binary Plist），不再使用 UserDefaults。
    ///
    /// - Important: 缺省为 **true**（开）。划词是一个「装上就该能用」的
    ///   功能，而它的失效方式是**完全静默**的：不弹菜单、不报错、不留痕迹。
    ///   若缺省关闭，新装用户会得到一个「看起来没生效」的功能，
    ///   且没有任何线索指向「去设置里打开它」。
    ///
    ///   插件整体已由 `policy: .enabledByDefault` 保证默认启用；
    ///   这里再缺省开启，保证「插件已启用」时功能就是开的。
    static var isEnabled: Bool {
        TextActionsPluginLocalStore.shared.isEnabled
    }

    @MainActor static func setEnabled(_ enabled: Bool) {
        TextActionsPluginLocalStore.shared.setEnabled(enabled)
        if enabled {
            TextSelectionManager.shared.startMonitoring()
        } else {
            TextSelectionManager.shared.stopMonitoring()
        }
    }
}

/// 选区监听与读取的调度者。
///
/// 三个依赖全部可注入（事件监听、选区读取、权限检查），默认值是生产实现；
/// 单测注入替身即可覆盖启动/停止/权限/重试时序，而不必碰真实的
/// `NSEvent` 全局监听与 Accessibility 授权弹窗。
///
/// 事件分流规则：
/// - **mouseUp**（拖拽、双击、三击完成选择）：总是重新评估选区；
/// - **keyUp**：仅在可能改变选区（带修饰键）或菜单仍可见时评估，
///   普通打字的击键不读 AX，避免无意义开销；
/// - 菜单因键盘输入消失后，同一选区不会因随后的 keyUp 复活
///   （`suppressedKeyboardText`，覆盖 Cmd+C 复制场景）。
@MainActor
final class TextSelectionManager: TextSelectionMonitoring {
    static let shared = TextSelectionManager()

    private(set) var isPermissionGranted = false
    private let eventMonitor: any TextEventMonitoring
    private let selectedTextProvider: any SelectedTextProviding
    private let permissionChecker: () -> Bool
    private var monitor: Any?

    /// 监听是否已注册。
    ///
    /// - Note: 划词功能失效时既不报错也不弹菜单，用户完全无从判断原因。
    ///   这个状态把「监听没起来」变成可观测事实，而不是静默失败。
    var isMonitoring: Bool { monitor != nil }

    /// 单调递增的评估代次：每次触发与每次外部消失都会使其递增，
    /// 进行中的异步读取在落地前比对代次，过期即弃——防止
    /// 「菜单已被按键收起，进行中的重试又把它弹出来」。
    private var evaluationToken = 0
    /// 键盘消失时展示的文本；同一选区不因 keyUp 复活。
    private var suppressedKeyboardText: String?
    /// 最近一次展示菜单的文本。
    private var lastPresentedText: String?

    init(
        eventMonitor: any TextEventMonitoring = SystemTextEventMonitor(),
        selectedTextProvider: any SelectedTextProviding = AccessibilitySelectedTextProvider(),
        permissionChecker: @escaping () -> Bool = {
            let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
    ) {
        self.eventMonitor = eventMonitor
        self.selectedTextProvider = selectedTextProvider
        self.permissionChecker = permissionChecker
        refreshPermission()
    }

    func refreshPermission() {
        isPermissionGranted = permissionChecker()
    }

    /// 请求辅助功能权限，并把结果同步回 `isPermissionGranted`。
    ///
    /// - Important: 系统弹窗是异步的，`AXIsProcessTrustedWithOptions` 在
    ///   调用返回时通常仍是未授权状态。因此**不能**用返回值来判断用户
    ///   是否已同意——真正的状态要在用户切回 Lumi 时重新读取
    ///   （见 `TextActionsSettingsView` 的激活监听）。
    ///
    /// - Returns: 请求发起后的状态，供调用方展示提示。
    @discardableResult
    func requestPermission() -> TextActionsPermissionService.Status {
        let status = TextActionsPermissionService.requestPermission()
        isPermissionGranted = status.isGranted
        if status.isGranted, TextActionsSettings.isEnabled {
            startMonitoring()
        }
        return status
    }

    /// 幂等：重复调用不会注册第二个监听器。
    ///
    /// 插件可能被反复 enable/disable，若不做 `monitor == nil` 短路，
    /// 同一事件会触发多次选区读取并叠加多个浮层。
    func startMonitoring() {
        guard monitor == nil else { return }
        refreshPermission()
        guard isPermissionGranted else { return }

        TextActionMenuController.shared.onDismiss = { [weak self] reason in
            self?.handleMenuDismissed(reason)
        }

        // 选区既可能由鼠标拖拽完成，也可能由 Shift/方向键完成；只监听
        // leftMouseUp 会漏掉后者。且部分应用在 mouseUp 后才更新 AXSelectedText。
        monitor = eventMonitor.addGlobalMonitor(
            matching: [.leftMouseUp, .rightMouseUp, .keyUp]
        ) { [weak self] event in
            // NSEvent 不可跨隔离域传递，先在回调线程提取值类型。
            let type = event.type
            let modifiers = event.modifierFlags
            let anchor = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleSelectionTrigger(type: type, modifiers: modifiers, anchor: anchor)
            }
        }
    }

    func stopMonitoring() {
        if let monitor {
            eventMonitor.removeMonitor(monitor)
            self.monitor = nil
        }
        evaluationToken += 1
        TextActionMenuController.shared.hide()
    }

    /// 菜单因外部事件（点击别处、按键、滚动）消失时的回调。
    private func handleMenuDismissed(_ reason: TextActionMenuDismissReason) {
        evaluationToken += 1
        switch reason {
        case .keyboard:
            // Cmd+C 等键盘消失：同一选区不被随后的 keyUp 复活。
            suppressedKeyboardText = lastPresentedText
            lastPresentedText = nil
        case .mouseDownOutside, .scroll, .actionPerformed, .programmatic:
            lastPresentedText = nil
        }
    }

    private func handleSelectionTrigger(
        type: NSEvent.EventType,
        modifiers: NSEvent.ModifierFlags,
        anchor: CGPoint
    ) {
        switch type {
        case .leftMouseUp, .rightMouseUp:
            suppressedKeyboardText = nil
            beginEvaluation(anchor: anchor)
        case .keyUp:
            let menuVisible = TextActionMenuController.shared.isVisible
            guard TextActionDismissPolicy.shouldEvaluateOnKeyUp(
                modifiers: modifiers, menuVisible: menuVisible
            ) else { return }
            beginEvaluation(anchor: anchor)
        default:
            break
        }
    }

    private func beginEvaluation(anchor: CGPoint) {
        guard isPermissionGranted else { return }
        evaluationToken += 1
        let token = evaluationToken
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 先等一轮再读：浏览器等 AX 客户端常在下一轮 runloop 才发布新选区。
            try? await Task.sleep(for: TextSelectionReadPolicy.initialDelay)
            for attempt in 0..<TextSelectionReadPolicy.retryCount {
                guard token == self.evaluationToken else { return }
                if let result = self.selectedTextProvider.readSelectedText(anchor: anchor),
                   TextSelectionReadPolicy.shouldPresentMenu(for: result.text) {
                    if result.text == self.suppressedKeyboardText {
                        return
                    }
                    self.suppressedKeyboardText = nil
                    self.lastPresentedText = result.text
                    TextActionMenuController.shared.show(selection: result)
                    return
                }
                if attempt < TextSelectionReadPolicy.retryCount - 1 {
                    try? await Task.sleep(for: TextSelectionReadPolicy.retryDelay)
                }
            }
            guard token == self.evaluationToken else { return }
            self.lastPresentedText = nil
            TextActionMenuController.shared.hide()
        }
    }
}

// MARK: - 浮层控制器

/// 菜单消失的原因。
enum TextActionMenuDismissReason {
    /// 点击了菜单外任意处。
    case mouseDownOutside
    /// 键盘输入（含 Esc 与快捷键）。
    case keyboard
    /// 滚动超过阈值。
    case scroll
    /// 菜单动作执行完毕（复制 / 搜索）。
    case actionPerformed
    /// 代码主动收起（插件停用、选区清空等）。
    case programmatic
}

/// 划词浮层的显示 / 消失 / 动作执行。
///
/// 显示策略对齐 PopClip：淡入出现在选区上方；点击外部、按键、滚动、
/// 动作完成后淡出。翻译是异步 LLM 调用，在浮层内展开结果卡片。
@MainActor
final class TextActionMenuController {
    static let shared = TextActionMenuController()

    /// 菜单因外部事件消失时通知 `TextSelectionManager`（抑制逻辑）。
    var onDismiss: (@MainActor (TextActionMenuDismissReason) -> Void)?

    private var panel: TextActionMenuPanel?
    private var hostingView: TextActionMenuHostingView?
    private let model = TextActionMenuModel()
    private var selection: SelectedText?
    private var dismissMonitor: Any?
    private var scrollAccumulation: CGFloat = 0
    private var translationTask: Task<Void, Never>?
    /// 复制反馈等延迟消失的代次，防止旧延迟任务收起新菜单。
    private var actionToken = 0
    private var isFadingOut = false

    private var translationProvider: (any LLMManaging)?

    var isVisible: Bool { panel?.isVisible == true && !isFadingOut }

    init() {
        model.onPerform = { [weak self] action in
            self?.perform(action)
        }
    }

    func configure(translationProvider: any LLMManaging) {
        self.translationProvider = translationProvider
    }

    // MARK: 显示 / 消失

    func show(selection: SelectedText) {
        // 打断进行中的淡出：新旧展示无缝衔接，不闪。
        if isFadingOut {
            isFadingOut = false
            panel?.animator().alphaValue = 1
        }

        // 文本变化 → 重置到动作条。全新展示（面板不可见）也重置——
        // 否则上次留下的翻译结果会顶替动作条出现在新一次划词上。
        let isFreshPresentation = panel?.isVisible != true
        if model.text != selection.text || (isFreshPresentation && model.state != .actions) {
            translationTask?.cancel()
            actionToken += 1
            model.text = selection.text
            model.state = .actions
        }
        self.selection = selection
        scrollAccumulation = 0

        ensurePanel()
        layoutPanel(animated: panel?.isVisible == true)

        if let panel, !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }
        }

        installDismissMonitorIfNeeded()
    }

    func hide(reason: TextActionMenuDismissReason = .programmatic) {
        guard let panel, panel.isVisible, !isFadingOut else { return }
        isFadingOut = true
        translationTask?.cancel()
        actionToken += 1
        removeDismissMonitor()
        onDismiss?(reason)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // completionHandler 保证在主线程调用。
            MainActor.assumeIsolated {
                guard let self, self.isFadingOut else { return }
                self.panel?.orderOut(nil)
                self.isFadingOut = false
            }
        })
    }

    // MARK: 动作执行

    private func perform(_ action: TextAction) {
        switch action {
        case .copy:
            action.perform(with: model.text)
            model.state = .copied
            actionToken += 1
            let token = actionToken
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self, token == self.actionToken else { return }
                self.hide(reason: .actionPerformed)
            }
        case .search:
            action.perform(with: model.text)
            hide(reason: .actionPerformed)
        case .translate:
            startTranslation()
        }
    }

    private func startTranslation() {
        translationTask?.cancel()
        guard let provider = translationProvider else {
            model.state = .failed(pluginLocalization.string("No translation provider is configured."))
            return
        }
        model.state = .translating
        let request = TextAction.v2TranslationRequest(for: model.text)
        translationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await provider.complete(request)
                guard !Task.isCancelled else { return }
                self.model.state = .translated(response.content)
            } catch is CancellationError {
                // 菜单已收起或文本已切换，静默丢弃。
            } catch {
                guard !Task.isCancelled else { return }
                self.model.state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: 面板管理

    private func ensurePanel() {
        guard panel == nil else { return }
        let hosting = TextActionMenuHostingView(rootView: TextActionMenuView(model: model))
        // 状态切换（动作条 ↔ 翻译卡片）由 SwiftUI 的实际布局结果驱动重排，
        // 不在 `onStateChange` 里同步量尺寸——那时 SwiftUI 还没刷新，
        // `fittingSize` 仍是上一状态的值，会把译文卡片裁在旧高度里。
        hosting.onIntrinsicSizeChange = { [weak self] size in
            self?.resizePanel(to: size, animated: true)
        }
        let panel = TextActionMenuPanel()
        panel.contentView = hosting
        self.hostingView = hosting
        self.panel = panel
    }

    private func layoutPanel(animated: Bool) {
        guard let hostingView else { return }
        hostingView.invalidateIntrinsicContentSize()
        resizePanel(to: hostingView.fittingSize, animated: animated)
    }

    private func resizePanel(to size: CGSize, animated: Bool) {
        guard let panel, let selection, size.width > 0, size.height > 0 else { return }
        // 初始展示时面板尚未 orderFront，不能以 isVisible 作为前置条件。
        guard !isFadingOut else { return }

        let anchor = selection.anchor
        let screen = NSScreen.screens.first(where: { NSMouseInRect(anchor, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let frame = TextActionMenuLayout.frame(
            selectionRect: selection.selectionRect,
            anchor: anchor,
            menuSize: size,
            screenFrame: screen.visibleFrame
        )
        guard frame != panel.frame else { return }
        if animated {
            panel.setFrame(frame, display: true, animate: true)
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    // MARK: 外部事件消失

    private func installDismissMonitorIfNeeded() {
        guard dismissMonitor == nil else { return }
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
            // 点击落在浮层自身上是进程内事件，不会进入全局监听，
            // 因此这里收到的一定是「菜单外」的事件。
            let type = event.type
            let modifiers = event.modifierFlags
            let deltaY = event.scrollingDeltaY
            Task { @MainActor [weak self] in
                self?.handleExternalEvent(type: type, modifiers: modifiers, deltaY: deltaY)
            }
        }
    }

    private func removeDismissMonitor() {
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
    }

    private func handleExternalEvent(
        type: NSEvent.EventType,
        modifiers: NSEvent.ModifierFlags,
        deltaY: CGFloat
    ) {
        switch type {
        case .leftMouseDown, .rightMouseDown:
            hide(reason: .mouseDownOutside)
        case .keyDown:
            if TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: modifiers) {
                hide(reason: .keyboard)
            }
        case .scrollWheel:
            scrollAccumulation += deltaY
            if abs(scrollAccumulation) > TextActionDismissPolicy.scrollThreshold {
                hide(reason: .scroll)
            }
        default:
            break
        }
    }
}

/// 文本操作设置页。
///
/// 布局遵循 settings-ui 规范：`PluginSettingsScaffold` + `AppSettingSection` +
/// `AppSettingRow`，不使用原生 `Form`——否则这一页会和其他设置入口
/// 呈现完全不同的原生分组样式，间距也对不齐。
struct TextActionsSettingsView: View {
    @ObservedObject private var permissionState: TextActionsPermissionState
    @LumiTheme private var theme
    @State private var enabled = TextActionsSettings.isEnabled

    init(permissionState: TextActionsPermissionState) {
        self._permissionState = ObservedObject(wrappedValue: permissionState)
    }

    var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Text Actions"),
            subtitle: pluginLocalization.string(
                "Show copy, search, and translation actions for selected text in other macOS apps."
            ),
            showHeader: false
        ) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(
                    title: pluginLocalization.string("General"),
                    titleAlignment: .leading
                ) {
                    VStack(spacing: 0) {
                        AppSettingToggleRow(
                            pluginLocalization.string("Enable selected-text actions"),
                            isOn: Binding(
                                get: { enabled },
                                set: { newValue in
                                    enabled = newValue
                                    TextActionsSettings.setEnabled(newValue)
                                }
                            )
                        )

                        Divider()
                            .padding(.vertical, 8)

                        permissionRow
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 辅助功能权限行。
    ///
    /// - Important: 这一行**必须**同时展示「当前状态」和「下一步动作」。
    ///   原文案只有一个「请求权限」按钮，而系统的授权弹窗在用户拒绝过一次
    ///   之后就不再出现——按钮会变成纯粹的空操作，用户既看不到状态，
    ///   也不知道还能做什么。现在显式区分三种情况：
    ///   - 已授权：只显示 ✅ 状态，按钮消失（没有可做的事）；
    ///   - 未授权：显示「请求权限」按钮（触发系统弹窗）；
    ///   - 并始终提供「打开系统设置」作为**兜底出口**——它是唯一在
    ///     系统弹窗失效后仍然有效的路径。
    private var permissionRow: some View {
        AppSettingRow(
            title: pluginLocalization.string("Accessibility Permission"),
            description: pluginLocalization.string(
                "Allows Lumi to read selected text in other apps."
            ),
            icon: "accessibility",
            titleSuffix: {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isGranted ? theme.success : theme.warning)
            }
        ) {
            HStack(spacing: 8) {
                if !isGranted {
                    AppButton(
                        pluginLocalization.string("Request Accessibility Permission"),
                        style: .secondary,
                        size: .small
                    ) {
                        permissionState.request()
                    }
                }
                AppButton(
                    pluginLocalization.string("Open System Settings"),
                    systemImage: "gearshape.fill",
                    style: .secondary,
                    size: .small
                ) {
                    permissionState.openSystemSettings()
                }
            }
        }
    }

    /// 是否已获得辅助功能权限。
    ///
    /// `permissionState.revision` 参与依赖，激活监听刷新后视图才会重绘。
    private var isGranted: Bool {
        _ = permissionState.revision
        return permissionState.status.isGranted
    }
}
