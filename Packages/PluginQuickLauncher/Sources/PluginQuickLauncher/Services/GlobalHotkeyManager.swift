import AppKit
import Carbon.HIToolbox
import LumiLoggingKit
import os

/// 全局热键组合（Carbon 键码 + 修饰键掩码）
public struct HotkeyCombo: Equatable, Codable, Sendable {
    /// Carbon 虚拟键码（如 kVK_Space = 49）
    public var keyCode: UInt32
    /// Carbon 修饰键掩码（cmdKey / optionKey / controlKey / shiftKey 的组合）
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// 默认热键：⌥Space
    public static let defaultCombo = HotkeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))

    /// 从 NSEvent 修饰键集合转换（用于设置页录制）
    public init(keyCode: UInt32, eventModifiers: NSEvent.ModifierFlags) {
        var carbon: UInt32 = 0
        if eventModifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if eventModifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if eventModifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if eventModifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        self.init(keyCode: keyCode, modifiers: carbon)
    }

    /// 是否包含至少一个功能修饰键（⌘/⌥/⌃，Shift 单独不算，避免与打字冲突）
    public var hasFunctionModifier: Bool {
        modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    /// 人类可读描述，如 "⌥Space"
    public var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    /// 常用键码的显示名（未覆盖的键码回退显示编号）
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Escape: return "Esc"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            // 字母 / 数字区：用 TIS 转换当前键盘布局的实际字符
            if let char = Self.character(for: keyCode), !char.isEmpty, char != "\u{1F}" {
                return char.uppercased()
            }
            return "Key \(keyCode)"
        }
    }

    /// 通过 UCKeyboardLayout 把键码转换为当前键盘布局下的字符（无修饰键状态）
    private static func character(for keyCode: UInt32) -> String? {
        var deadKeyState: UInt32 = 0
        var actualLength: Int = 0
        var unicode: [UniChar] = [0, 0]
        let keyboardLayout = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutDataPtr = TISGetInputSourceProperty(keyboardLayout, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let layout: UnsafePointer<UCKeyboardLayout> = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            unicode.count,
            &actualLength,
            &unicode
        )
        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: unicode, count: actualLength)
    }
}

/// 系统级全局热键管理器（Carbon RegisterEventHotKey）
///
/// 负责注册 / 注销全局热键，热键触发时回调 `onToggle`。
/// 热键组合持久化在 UserDefaults，修改后立即热切换。
@MainActor
public final class GlobalHotkeyManager: NSObject, ObservableObject, SuperLog {
    public nonisolated static let emoji = "⌨️"
    public nonisolated static let verbose: Bool = false

    public static let shared = GlobalHotkeyManager()

    // MARK: - State

    /// 热键触发回调（toggle 启动器窗口）
    public var onToggle: (() -> Void)?

    /// 当前生效的热键组合
    @Published public private(set) var currentCombo: HotkeyCombo = .defaultCombo

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let defaults: UserDefaults

    private static let keyCodeKey = "QuickLauncher.Hotkey.keyCode"
    private static let modifiersKey = "QuickLauncher.Hotkey.modifiers"

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 恢复持久化的热键组合
        if let data = defaults.data(forKey: Self.keyCodeKey + ".encoded"),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            super.init()
            currentCombo = combo
        } else {
            // 兼容：直接存数值的旧格式 / 默认值
            let keyCode = UInt32(exactly: defaults.integer(forKey: Self.keyCodeKey)) ?? 0
            let modifiers = UInt32(exactly: defaults.integer(forKey: Self.modifiersKey)) ?? 0
            super.init()
            if keyCode != 0 {
                currentCombo = HotkeyCombo(keyCode: keyCode, modifiers: modifiers)
            }
        }
    }

    // MARK: - Lifecycle

    /// 开始监听全局热键（重复调用安全）
    public func start() {
        installEventHandlerIfNeeded()
        registerHotkey()
    }

    /// 停止监听
    public func stop() {
        unregisterHotkey()
    }

    /// 更新热键组合：持久化并热切换。
    ///
    /// 监听中时**先注册新组合、成功才提交状态**：注册失败（组合被其它应用占用）
    /// 时原热键保持注册、`currentCombo` 与持久化配置都不变，返回 `false`（#454）。
    /// 未监听时只更新状态，总是返回 `true`。
    /// - Returns: 注册是否成功（或无需注册）。
    @discardableResult
    public func updateCombo(_ combo: HotkeyCombo) -> Bool {
        guard combo != currentCombo else { return true }
        if eventHandler != nil {
            guard let newRef = makeRegistration(for: combo) else { return false }
            // 新组合已注册成功：换掉旧注册（先注册后注销，失败时原热键不受影响）。
            unregisterHotkey()
            hotKeyRef = newRef
        }
        currentCombo = combo
        persist(combo)
        return true
    }

    /// 恢复默认 ⌥Space
    public func resetToDefault() {
        updateCombo(.defaultCombo)
    }

    // MARK: - Registration

    /// 注册指定组合，返回热键引用；失败（如组合被占用）时返回 nil 并记录日志。
    private func makeRegistration(for combo: HotkeyCombo) -> EventHotKeyRef? {
        let hotKeyID = EventHotKeyID(signature: Self.eventSignature, id: 1)
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newRef
        )
        guard status == noErr, let newRef else {
            QuickLauncherPluginSupport.logger.error("\(self.t)注册全局热键失败: \(status) (\(combo.displayString))")
            return nil
        }
        return newRef
    }

    private func registerHotkey() {
        if let newRef = makeRegistration(for: currentCombo) {
            unregisterHotkey()
            hotKeyRef = newRef
            if Self.verbose {
                QuickLauncherPluginSupport.logger.info("\(self.t)全局热键已注册: \(self.currentCombo.displayString)")
            }
        }
        // 注册失败（如重复 start 或组合被占用）时保留既有注册，不撤掉原热键。
    }

    private func persist(_ combo: HotkeyCombo) {
        if let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: Self.keyCodeKey + ".encoded")
        }
        defaults.set(Int(exactly: combo.keyCode) ?? 0, forKey: Self.keyCodeKey)
        defaults.set(Int(exactly: combo.modifiers) ?? 0, forKey: Self.modifiersKey)
    }

    private func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    // MARK: - Event Handler

    private static let eventSignature: OSType = 0x4C_75_6D_30 // 'Lum0'

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == GlobalHotkeyManager.eventSignature else { return noErr }
            // Carbon 热键事件在主线程事件循环派发，可安全断言 MainActor
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated {
                manager.fireToggle()
            }
            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        var newHandler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPointer,
            &newHandler
        )
        guard installStatus == noErr, let newHandler else {
            QuickLauncherPluginSupport.logger.error("\(self.t)安装热键事件处理器失败: \(installStatus)")
            return
        }
        eventHandler = newHandler
    }

    private func fireToggle() {
        onToggle?()
    }
}
