import AppKit
import Carbon.HIToolbox
import Foundation

/// 启动器设置页的唯一数据来源。
///
/// 负责全局热键展示/录制、内容源开关的持久化读写等业务状态；
/// View 只读取本 ViewModel，不再直接接触 `GlobalHotkeyManager` 或 `UserDefaults`。
@MainActor
final class QuickLauncherSettingsViewModel: ObservableObject {
    private enum SourceKeys {
        static let apps = "QuickLauncher.Source.apps"
        static let files = "QuickLauncher.Source.files"
        static let commands = "QuickLauncher.Source.commands"
    }

    private let hotkeyManager: GlobalHotkeyManager

    // MARK: - Published State (供 View 展示)

    /// 内容源开关（持久化到 UserDefaults，与旧 @AppStorage 键一致）。
    @Published var appsEnabled: Bool {
        didSet { UserDefaults.standard.set(appsEnabled, forKey: SourceKeys.apps) }
    }
    @Published var filesEnabled: Bool {
        didSet { UserDefaults.standard.set(filesEnabled, forKey: SourceKeys.files) }
    }
    @Published var commandsEnabled: Bool {
        didSet { UserDefaults.standard.set(commandsEnabled, forKey: SourceKeys.commands) }
    }

    /// 是否正在录制全局热键。
    @Published private(set) var isRecording = false
    private var recordMonitor: Any?

    /// 热键注册失败的提示（组合可能被其它应用占用）。注册成功时清空。
    @Published private(set) var errorMessage: String?

    init(hotkeyManager: GlobalHotkeyManager) {
        self.hotkeyManager = hotkeyManager
        let defaults = UserDefaults.standard
        appsEnabled = defaults.object(forKey: SourceKeys.apps) as? Bool ?? true
        filesEnabled = defaults.object(forKey: SourceKeys.files) as? Bool ?? true
        commandsEnabled = defaults.object(forKey: SourceKeys.commands) as? Bool ?? true
    }

    // MARK: - 派生状态

    var currentComboDisplay: String {
        hotkeyManager.currentCombo.displayString
    }

    // MARK: - 用户意图

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        errorMessage = nil
        // 应用内监听下一次按键组合
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return nil }
            let combo = HotkeyCombo(
                keyCode: UInt32(event.keyCode),
                eventModifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            )
            // 至少一个功能修饰键才有效；Esc 取消录制
            if event.keyCode == kVK_Escape {
                self.stopRecording()
            } else if combo.hasFunctionModifier {
                self.applyCombo(combo)
                self.stopRecording()
            }
            return nil
        }
    }

    /// 应用新热键组合：注册失败时提示冲突，原组合保持不变（#454）。
    func applyCombo(_ combo: HotkeyCombo) {
        if hotkeyManager.updateCombo(combo) {
            errorMessage = nil
        } else {
            errorMessage = pluginLocalization.string(
                "Hotkey registration failed. The combination may be in use by another app."
            )
        }
    }

    func stopRecording() {
        if let recordMonitor {
            NSEvent.removeMonitor(recordMonitor)
            self.recordMonitor = nil
        }
        isRecording = false
    }

    func resetHotkey() {
        applyCombo(.defaultCombo)
    }
}
