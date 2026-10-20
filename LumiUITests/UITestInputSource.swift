import Carbon
import Foundation

/// UI 测试期间的输入源守卫。
///
/// ## 为什么需要它
///
/// `XCUIElement.typeText` 是逐字符派发合成键盘事件，会进入宿主当前输入法的
/// 组合态。宿主启用中文拼音时，实测**每次都恰好丢掉最后一个空格**：
///
/// | 写入方式 | 期望 | 实际 |
/// |---|---|---|
/// | `typeText`（中文输入法下） | `UI Testing Send Button Probe`（28） | `…Probe`（27）❌ |
/// | `typeText`（中文输入法下） | `PROBE MESSAGE UNIQUE TEXT`（25） | `PROBE MESSAGE UNIQUETEXT`（24）❌ |
/// | 剪贴板 + ⌘V | 以上全部 | 完整无损 ✅ |
///
/// 丢一个尾部空格会让「按完整文案断言消息是否上屏」的用例**必然失败**，
/// 且现象极具误导性——界面上的用户消息明明在，内容却对不上，
/// 很容易被误判成渲染缺陷或元素定位失败。
///
/// ## 为什么运行时切输入源，而不是加启动参数
///
/// 既有的 `LumiUITestCase` 注释记着一条实测结论：`-AppleInputSourceOverride`
/// 解决不了这个问题，它只影响 TIS 输入源选择、不阻止候选栏弹出。
/// 那条结论本身没错，但它否定的只是**那个参数**——该参数由系统在启动时
/// 套用，无法强制覆盖用户已启用的输入源。
///
/// 运行时用 TIS 切换是另一条路径，本文件走的就是它。
///
/// ## 为什么这能证明切输入源是有效的
///
/// 上面那张表本身就是证据：如果输入源状态不影响 `typeText`，中文输入法
/// 就不可能「恰好」吃掉尾部空格。是 IME 组合态吃掉了它——而 IME 组合态
/// 只在当前输入源是非拉丁布局时才会出现。因此切到 ASCII 布局后，
/// 该路径不复存在。这同时说明 XCUITest 派发的合成按键确实经过系统的
/// 正常输入处理链路，切换输入源对它有效。
///
/// - Important: 输入源是**用户的全局状态**，切换后必须还原，否则会改掉
///   开发者的输入法配置——比脏剪贴板更严重。
enum UITestInputSource {
    /// US 键盘布局的输入源 ID。
    ///
    /// 用布局 ID 而非某个「英文名」的输入源：后者依赖用户装了哪个键盘
    /// （如 ABC、British、Australian），在没装的机器上根本不存在。
    /// `com.apple.keylayout.ABC` 是 macOS 的 US 布局，必定存在。
    static let usKeyboardLayoutID = "com.apple.keylayout.ABC"

    /// 切换到英文（ASCII）输入源，返回原始输入源 ID 供后续还原。
    ///
    /// - Returns: 切换前的输入源 ID；切换失败时返回 `nil`。
    ///   调用方**必须**在 tearDown 中还原，否则会留下全局副作用。
    @discardableResult
    static func switchToEnglish(timeout: TimeInterval = 5) -> String? {
        let originalID = currentID()
        guard let target = findASCIIInputSource() else { return nil }
        guard TISEnableInputSource(target) == noErr || isEnabled(target) else { return nil }
        guard TISSelectInputSource(target) == noErr else { return nil }
        guard waitForCurrentID(target, timeout: timeout) else { return nil }
        return originalID
    }

    /// 把输入源还原为给定 ID。
    ///
    /// 还原失败不抛错：tearDown 里抛错会掩盖用例本身的真实失败。
    static func restore(_ originalID: String) {
        guard let source = inputSources(enabledOnly: true).first(where: { id(of: $0) == originalID })
            ?? inputSources(enabledOnly: false).first(where: { id(of: $0) == originalID })
        else { return }
        _ = TISSelectInputSource(source)
    }

    // MARK: - 私有

    private static func currentID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return id(of: source)
    }

    private static func id(of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func isEnabled(_ source: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }

    private static func isASCIICapable(_ source: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }

    /// 列出输入源。
    ///
    /// `enabledOnly == false` 时用 `AppleEnabledInputSources` 过滤器拿到
    /// **全部可选**输入源——用户没启用的 US 布局也能取到，再经
    /// `TISEnableInputSource` 启用，不必去系统设置里手工勾选。
    private static func inputSources(enabledOnly: Bool) -> [TISInputSource] {
        if enabledOnly {
            return TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        }
        // kTISCategoryAll 未导入到 Swift，用其字面值（Carbon 头文件中的同一常量）。
        let filter = [kTISPropertyInputSourceCategory: "TISCategoryAll"] as CFDictionary
        return TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    /// 找可用的 ASCII 输入源：优先 US 布局，回退到任意 ASCII 能力布局。
    private static func findASCIIInputSource() -> TISInputSource? {
        if let exact = inputSources(enabledOnly: true).first(where: { id(of: $0) == usKeyboardLayoutID })
            ?? inputSources(enabledOnly: false).first(where: { id(of: $0) == usKeyboardLayoutID })
        {
            return exact
        }
        return inputSources(enabledOnly: true).first(where: isASCIICapable)
            ?? inputSources(enabledOnly: false).first(where: isASCIICapable)
    }

    /// 轮询等待切换生效。
    ///
    /// `TISSelectInputSource` 返回时系统尚未完成切换，立刻 `typeText`
    /// 仍会落在旧输入源上。切输入源有延迟，不能靠固定 sleep 赌。
    private static func waitForCurrentID(_ expected: TISInputSource, timeout: TimeInterval) -> Bool {
        let expectedID = id(of: expected)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let current = currentID(), current == expectedID { return true }
            usleep(50_000)
        }
        return currentID() == expectedID
    }
}
