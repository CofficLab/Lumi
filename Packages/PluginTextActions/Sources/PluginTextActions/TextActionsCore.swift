import AppKit
import KitLLM

// MARK: - 选区读取策略

/// 选区读取的纯策略：延迟、重试次数与「是否值得弹菜单」的判定。
///
/// 把这三件事从 `TextSelectionManager` 里抽出来，使时序与判定可被单元测试直接覆盖，
/// 而不必真的构造 AX 调用与 `NSEvent` 全局监听。
enum TextSelectionReadPolicy {
    /// 首次读取前的等待：AX 客户端（如浏览器）常在下一轮 runloop 才发布新选区。
    static let initialDelay: Duration = .milliseconds(60)
    /// 每次重试之间的间隔。
    static let retryDelay: Duration = .milliseconds(100)
    /// 读取失败时的最大尝试次数。
    static let retryCount = 3

    /// 选区为空或仅含空白时**不弹菜单**——否则用户会在空白处也看到浮层。
    static func shouldPresentMenu(for text: String?) -> Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 坐标换算

/// Quartz 屏幕坐标（原点在主屏左上角、y 向下）与 Cocoa 屏幕坐标
///（原点在主屏左下角、y 向上）之间的换算。
///
/// Accessibility API 返回的选区 bounds 是 Quartz 坐标；`NSWindow.frame`
/// 与 `NSEvent.mouseLocation` 是 Cocoa 坐标。多屏环境下该换算同样成立
/// ——AX 坐标以主屏左上角为全局原点。
enum TextActionCoordinates {
    static func quartzToCocoa(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

// MARK: - 菜单布局

/// 菜单浮层的纯布局计算：相对选区定位并夹取到屏幕内。
///
/// 交互对齐 PopClip / Easydict：菜单出现在**选区上方居中**；上方空间不足
/// 时放到选区下方；两侧都放不下时夹回屏幕内。没有选区 bounds（部分应用
/// 不实现 `AXBoundsForRange`）时退回锚点（鼠标位置）上方。
struct TextActionMenuLayout {
    static func frame(
        selectionRect: CGRect?,
        anchor: CGPoint,
        menuSize: CGSize,
        screenFrame: CGRect,
        margin: CGFloat = 8,
        gap: CGFloat = 6
    ) -> CGRect {
        let centerX: CGFloat
        let aboveY: CGFloat
        let belowY: CGFloat
        if let selectionRect {
            centerX = selectionRect.midX
            aboveY = selectionRect.maxY + gap
            belowY = selectionRect.minY - menuSize.height - gap
        } else {
            centerX = anchor.x
            aboveY = anchor.y + 14
            belowY = anchor.y - menuSize.height - 14
        }

        let minX = screenFrame.minX + margin
        let maxX = screenFrame.maxX - menuSize.width - margin
        let x = min(max(centerX - menuSize.width / 2, minX), max(minX, maxX))

        let maxY = screenFrame.maxY - margin
        let minY = screenFrame.minY + margin
        let y: CGFloat
        if aboveY + menuSize.height <= maxY {
            y = aboveY
        } else if belowY >= minY {
            y = belowY
        } else {
            y = min(max(aboveY, minY), max(minY, maxY - menuSize.height))
        }

        return CGRect(x: x, y: y, width: menuSize.width, height: menuSize.height)
    }
}

// MARK: - 多屏选屏

/// 浮层目标屏幕的选择。
///
/// 键盘触发选区时鼠标可能停在另一块屏幕（例如在副屏 Shift+方向键选词，
/// 鼠标留在主屏）。因此有可用的选区 bounds 时以选区中心为准，只有
/// bounds 缺失或落在所有屏幕之外时才回退到鼠标锚点。
enum TextActionScreenSelection {
    static func referencePoint(selectionRect: CGRect?, anchor: CGPoint) -> CGPoint {
        guard let selectionRect, selectionRect.width > 0, selectionRect.height > 0 else {
            return anchor
        }
        return CGPoint(x: selectionRect.midX, y: selectionRect.midY)
    }

    static func screenIndex(
        selectionRect: CGRect?,
        anchor: CGPoint,
        screenFrames: [CGRect]
    ) -> Int? {
        let reference = referencePoint(selectionRect: selectionRect, anchor: anchor)
        if let index = screenFrames.firstIndex(where: { NSMouseInRect(reference, $0, false) }) {
            return index
        }
        return screenFrames.firstIndex(where: { NSMouseInRect(anchor, $0, false) })
    }
}

// MARK: - 消失策略

/// 菜单消失判定的纯逻辑，与全局事件监听解耦以便单测。
///
/// 规则参考 Easydict / Xpop 的实测体验：
/// - 点击菜单外任意处、滚动超过阈值、按键输入 → 消失；
/// - 仅按 Shift（Shift+方向键调整选区）不消失——消失交给 keyUp 后的
///   选区重读来更新位置，否则调整选区时菜单会闪烁。
enum TextActionDismissPolicy {
    /// 滚动消失的累计阈值（pt）。轻微触控板滚动不应收起菜单。
    static let scrollThreshold: CGFloat = 60

    /// 键盘按下是否应让菜单消失。
    ///
    /// 组合键中只有 Shift（选区调整）豁免；Cmd+C 等快捷键与普通输入都消失。
    static func shouldDismissOnKeyDown(modifiers: NSEvent.ModifierFlags) -> Bool {
        modifiers.intersection([.shift, .command, .control, .option]) == [.shift] ? false : true
    }

    /// keyUp 是否值得触发一次选区重读。
    ///
    /// 普通打字的 keyUp 不读 AX——菜单已被 keyDown 收起，且每次击键都读
    /// AX 是不必要的开销。只有可能改变选区的按键（带修饰键，如
    /// Shift+方向键、Cmd+A）或菜单仍在显示时才重读。
    static func shouldEvaluateOnKeyUp(modifiers: NSEvent.ModifierFlags, menuVisible: Bool) -> Bool {
        if menuVisible { return true }
        return modifiers.intersection([.shift, .command, .control, .option]).isEmpty == false
    }

    /// 事件是否落在浮层自身窗口内。
    ///
    /// 全局监听收不到本进程事件，因此点击 Lumi 自己的窗口需要本地监听
    /// 兜底；但落在浮层上的点击与滚动（译文卡片可滚动）不能收起菜单。
    /// `windowNumber` 为 0 表示事件尚未绑定窗口，不能拿来与面板比较。
    static func isInsidePanel(eventWindowNumber: Int, panelWindowNumber: Int) -> Bool {
        panelWindowNumber != 0 && eventWindowNumber == panelWindowNumber
    }
}

// MARK: - 动作目录

/// 选区浮层提供的动作。每个 case 对应一个菜单项。
enum TextAction: CaseIterable, Identifiable {
    case copy
    case search
    case translate

    var id: Self { self }

    var title: String {
        switch self {
        case .copy: pluginLocalization.string("Copy")
        case .search: pluginLocalization.string("Search")
        case .translate: pluginLocalization.string("Translate")
        }
    }

    var systemImage: String {
        switch self {
        case .copy: "doc.on.doc"
        case .search: "magnifyingglass"
        case .translate: "character.book.closed"
        }
    }

    /// 用 `URLComponents` 构造查询 URL，由系统负责百分号编码。
    ///
    /// 直接字符串拼接会在 `&`、空格、非 ASCII 上出错——选区文本是用户自由输入。
    static func searchURL(for text: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        return components?.url
    }

    /// 翻译请求：system 指令固定译入简体中文，user 消息为原文。
    static func v2TranslationRequest(for text: String) -> LLMRequest {
        LLMRequest(messages: [
            LLMMessage(
                role: .system,
                content: "You are a concise translation assistant. Translate the user's selected text into Simplified Chinese. Preserve meaning, tone, formatting, and line breaks. Return only the translation without explanations."
            ),
            LLMMessage(role: .user, content: text),
        ])
    }

    /// 旧版翻译请求，与 `v2TranslationRequest` 同语义不同载体，供迁移期兼容。
    static func translationRequest(for text: String) -> LLMRequest {
        v2TranslationRequest(for: text)
    }

    /// 同步动作（复制 / 搜索）的执行入口。
    ///
    /// 翻译是异步 LLM 调用且要在浮层内展示进度与结果，由
    /// `TextActionMenuController` 接管，不走这里。
    func perform(with text: String) {
        switch self {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .search:
            guard let url = Self.searchURL(for: text) else { return }
            NSWorkspace.shared.open(url)
        case .translate:
            break
        }
    }
}

// MARK: - 依赖边界

/// 全局鼠标/键盘事件监听能力的抽象。
///
/// 抽成协议是为了让 `TextSelectionManager` 能在测试中注入替身，
/// 避免单测真的注册系统级全局监听器。
@MainActor
protocol TextEventMonitoring {
    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any?
    func removeMonitor(_ monitor: Any)
}

/// 选区监听启停的最小契约。
///
/// 插件只依赖「启动 / 停止监听」两件事，抽出协议后单测可注入替身，
/// 从而**不注册真实的全局事件监听**就能断言监听是否被启动——
/// 这正是回归「冷启动不启动监听」所必需的可观测点。
@MainActor
public protocol TextSelectionMonitoring: AnyObject {
    /// 监听当前是否已注册。
    ///
    /// - Note: 划词功能失效时既不报错也不弹菜单，用户完全无从判断原因。
    ///   这个状态让「监听没起来」变成可观测事实，而不是静默失败。
    var isMonitoring: Bool { get }

    /// 启动选区监听。幂等：重复调用不会注册第二个监听器。
    func startMonitoring()

    /// 停止选区监听。
    func stopMonitoring()
}

/// 读取当前焦点元素的选区文本。
@MainActor
protocol SelectedTextProviding {
    func readSelectedText(anchor: CGPoint) -> SelectedText?
}

/// 一次成功的选区读取结果。
struct SelectedText: Sendable, Equatable {
    let text: String
    /// 触发时的鼠标位置（Cocoa 坐标），无选区 bounds 时的定位回退。
    let anchor: CGPoint
    /// 选区在屏幕上的 bounds（Cocoa 坐标）；应用不支持 `AXBoundsForRange` 时为 nil。
    var selectionRect: CGRect? = nil
}

@MainActor
struct AccessibilitySelectedTextProvider: SelectedTextProviding {
    func readSelectedText(anchor: CGPoint) -> SelectedText? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success else { return nil }
        // CopyAttributeValue 会把任意 CFTypeRef 塞进 out 参数，必须先验类型再强转。
        guard let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        let focused = focusedValue as! AXUIElement

        // 密码框不弹菜单。多数安全输入框的 AXSelectedText 本就取不到值，
        // 这里再显式排除一层，避免未来 macOS 行为变化带来泄露风险。
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &roleValue) == .success,
           (roleValue as? String) == "AXSecureTextField" {
            return nil
        }

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let text = selectedValue as? String else { return nil }

        return SelectedText(text: text, anchor: anchor, selectionRect: selectionBounds(of: focused))
    }

    /// 读取选区的屏幕 bounds，并换算成 Cocoa 坐标。
    ///
    /// 链路：`AXSelectedTextRange` → 作为参数传给 `AXBoundsForRange`。
    /// 任一环节失败（应用不实现、选区跨多行只取首段等）都回退 nil，
    /// 由布局层改用鼠标锚点。
    private func selectionBounds(of element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
        let rangeValue,
        CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        let rangeAX = rangeValue as! AXValue
        guard AXValueGetType(rangeAX) == .cfRange else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAX,
            &boundsValue
        ) == .success,
        let boundsValue,
        CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }
        let boundsAX = boundsValue as! AXValue
        guard AXValueGetType(boundsAX) == .cgRect else { return nil }

        var quartzRect = CGRect.zero
        guard AXValueGetValue(boundsAX, .cgRect, &quartzRect),
              quartzRect.width > 0, quartzRect.height > 0 else { return nil }

        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        return TextActionCoordinates.quartzToCocoa(quartzRect, primaryScreenHeight: primaryHeight)
    }
}

@MainActor
final class SystemTextEventMonitor: TextEventMonitoring {
    func addGlobalMonitor(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any? {
        NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}
