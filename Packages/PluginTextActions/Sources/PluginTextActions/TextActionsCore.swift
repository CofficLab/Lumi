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

// MARK: - 菜单布局

/// 菜单浮层的纯布局计算：把锚点转成不越界的矩形。
///
/// 抽成纯函数后，屏幕边缘的夹取逻辑可被直接断言，无需真实窗口。
struct TextActionMenuLayout {
    static func frame(
        for anchor: CGPoint,
        menuSize: CGSize,
        screenFrame: CGRect,
        margin: CGFloat = 8,
        verticalOffset: CGFloat = 18
    ) -> CGRect {
        let maxX = screenFrame.maxX - menuSize.width - margin
        let maxY = screenFrame.maxY - menuSize.height - margin
        return CGRect(
            x: min(max(anchor.x - menuSize.width / 2, screenFrame.minX), maxX),
            y: min(anchor.y + verticalOffset, maxY),
            width: menuSize.width,
            height: menuSize.height
        )
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

/// 读取当前焦点元素的选区文本。
@MainActor
protocol SelectedTextProviding {
    func readSelectedText(anchor: CGPoint) -> SelectedText?
}

/// 一次成功的选区读取结果。
struct SelectedText: Sendable, Equatable {
    let text: String
    let anchor: CGPoint
}

@MainActor
struct AccessibilitySelectedTextProvider: SelectedTextProviding {
    nonisolated func readSelectedText(anchor: CGPoint) -> SelectedText? {
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

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let text = selectedValue as? String else { return nil }

        return SelectedText(text: text, anchor: anchor)
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
