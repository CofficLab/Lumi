import AppKit
import Carbon.HIToolbox
import LumiUI
import SwiftUI

/// 启动器设置页：全局热键录制 + 内容源开关
public struct LauncherSettingsView: View {
    @ObservedObject private var hotkeyManager: GlobalHotkeyManager
    @AppStorage("QuickLauncher.Source.apps") private var appsEnabled = true
    @AppStorage("QuickLauncher.Source.files") private var filesEnabled = true
    @AppStorage("QuickLauncher.Source.commands") private var commandsEnabled = true

    @State private var isRecording = false
    @State private var recordMonitor: Any?

    init(hotkeyManager: GlobalHotkeyManager) {
        self.hotkeyManager = hotkeyManager
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
#if DEBUG
                HStack {
                    Spacer()
                    AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", style: .warning, size: .small) {
                        openDataDirectory()
                    }
                }
#endif
                hotkeySection
                sourcesSection
                usageSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        AppSettingSection(
            title: LumiPluginLocalization.string("Global Hotkey", bundle: .module),
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: LumiPluginLocalization.string("Toggle Launcher", bundle: .module),
                description: LumiPluginLocalization.string("Press the hotkey anywhere to open the launcher. Click Record, then press a key combination with ⌘/⌥/⌃.", bundle: .module),
                icon: "command"
            ) {
                HStack(spacing: 8) {
                    AppTag(hotkeyManager.currentCombo.displayString, systemImage: "command", style: .accent)

                    if isRecording {
                        AppButton(
                            LumiPluginLocalization.string("Cancel", bundle: .module),
                            systemImage: "xmark",
                            style: .secondary,
                            size: .small
                        ) {
                            stopRecording()
                        }
                    } else {
                        AppButton(
                            LumiPluginLocalization.string("Record", bundle: .module),
                            systemImage: "record.circle",
                            style: .secondary,
                            size: .small
                        ) {
                            startRecording()
                        }
                        AppButton(
                            LumiPluginLocalization.string("Reset", bundle: .module),
                            systemImage: "arrow.counterclockwise",
                            style: .secondary,
                            size: .small
                        ) {
                            hotkeyManager.resetToDefault()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        AppSettingSection(
            title: LumiPluginLocalization.string("Search Sources", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Applications", bundle: .module),
                    icon: "app.fill",
                    isOn: $appsEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Files (Spotlight)", bundle: .module),
                    icon: "doc.text.magnifyingglass",
                    isOn: $filesEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Commands", bundle: .module),
                    icon: "terminal",
                    isOn: $commandsEnabled
                )
            }
        }
    }

    // MARK: - Usage

    private var usageSection: some View {
        AppSettingSection(
            title: LumiPluginLocalization.string("How to Use", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                instructionRow(
                    key: hotkeyManager.currentCombo.displayString,
                    description: LumiPluginLocalization.string("Open the launcher anywhere", bundle: .module),
                    icon: "command"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "?",
                    description: LumiPluginLocalization.string("Prefix with ? to ask Lumi directly", bundle: .module),
                    icon: "questionmark"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "↑ ↓",
                    description: LumiPluginLocalization.string("Navigate results", bundle: .module),
                    icon: "arrow.up.arrow.down"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "↩",
                    description: LumiPluginLocalization.string("Open / execute selected result", bundle: .module),
                    icon: "return"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "Esc",
                    description: LumiPluginLocalization.string("Close the launcher", bundle: .module),
                    icon: "escape"
                )
            }
        }
    }

    private func instructionRow(key: String, description: String, icon: String) -> some View {
        AppSettingRow(
            title: description,
            icon: icon
        ) {
            AppTag(key, style: .subtle)
        }
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        // 应用内监听下一次按键组合
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            let combo = HotkeyCombo(
                keyCode: UInt32(event.keyCode),
                eventModifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            )
            // 至少一个功能修饰键才有效；Esc 取消录制
            if event.keyCode == kVK_Escape {
                stopRecording()
            } else if combo.hasFunctionModifier {
                hotkeyManager.updateCombo(combo)
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let recordMonitor {
            NSEvent.removeMonitor(recordMonitor)
            self.recordMonitor = nil
        }
        isRecording = false
    }

    // MARK: - Debug Helpers

    #if DEBUG
    private func openDataDirectory() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
        guard let url = appSupport else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
    #endif
}

#Preview("Launcher Settings") {
    LauncherSettingsView(hotkeyManager: GlobalHotkeyManager.shared)
        .inRootView()
        .frame(width: 600, height: 520)
}
