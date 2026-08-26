import AppKit
import Carbon.HIToolbox
import LumiUI
import SwiftUI

/// 启动器设置页：全局热键录制 + 内容源开关
public struct LauncherSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var hotkeyManager = GlobalHotkeyManager.shared
    @AppStorage("QuickLauncher.Source.apps") private var appsEnabled = true
    @AppStorage("QuickLauncher.Source.files") private var filesEnabled = true
    @AppStorage("QuickLauncher.Source.commands") private var commandsEnabled = true

    @State private var isRecording = false
    @State private var recordMonitor: Any?

    public init() {}

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Quick Launcher", bundle: .module),
            subtitle: LumiPluginLocalization.string("Raycast-style global launcher", bundle: .module),
            showHeader: false
        ) {
            hotkeyCard
            sourcesCard
            usageCard
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Hotkey

    private var hotkeyCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("Global Hotkey", bundle: .module),
                spacing: 12
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Text(LumiPluginLocalization.string("Toggle Launcher", bundle: .module))
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Text(verbatim: hotkeyManager.currentCombo.displayString)
                            .font(.appBody)
                            .fontDesign(.monospaced)
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.appAccentSoftFill)
                            )

                        if isRecording {
                            Button(LumiPluginLocalization.string("Cancel", bundle: .module)) {
                                stopRecording()
                            }
                        } else {
                            Button(LumiPluginLocalization.string("Record", bundle: .module)) {
                                startRecording()
                            }
                            Button(LumiPluginLocalization.string("Reset", bundle: .module)) {
                                hotkeyManager.resetToDefault()
                            }
                        }
                    }
                }

                Text(LumiPluginLocalization.string("Press the hotkey anywhere to open the launcher. Click Record, then press a key combination with ⌘/⌥/⌃.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("Search Sources", bundle: .module),
                spacing: 8
            ) {
                Toggle(isOn: $appsEnabled) {
                    Text(LumiPluginLocalization.string("Applications", bundle: .module))
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }
                .toggleStyle(.switch)

                Toggle(isOn: $filesEnabled) {
                    Text(LumiPluginLocalization.string("Files (Spotlight)", bundle: .module))
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }
                .toggleStyle(.switch)

                Toggle(isOn: $commandsEnabled) {
                    Text(LumiPluginLocalization.string("Commands", bundle: .module))
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Usage

    private var usageCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("How to Use", bundle: .module),
                spacing: 8
            ) {
                instructionRow(
                    key: hotkeyManager.currentCombo.displayString,
                    description: LumiPluginLocalization.string("Open the launcher anywhere", bundle: .module)
                )
                instructionRow(
                    key: "?",
                    description: LumiPluginLocalization.string("Prefix with ? to ask Lumi directly", bundle: .module)
                )
                instructionRow(
                    key: "↑ ↓",
                    description: LumiPluginLocalization.string("Navigate results", bundle: .module)
                )
                instructionRow(
                    key: "↩",
                    description: LumiPluginLocalization.string("Open / execute selected result", bundle: .module)
                )
                instructionRow(
                    key: "Esc",
                    description: LumiPluginLocalization.string("Close the launcher", bundle: .module)
                )
            }
        }
    }

    private func instructionRow(key: String, description: String) -> some View {
        AppSettingsRow(verticalPadding: 6) {
            HStack(spacing: 12) {
                Text(key)
                    .font(.appBody)
                    .fontDesign(.monospaced)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.appAccentSoftFill)
                    )

                Text(description)
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)

                Spacer()
            }
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
}

#Preview("Launcher Settings") {
    LauncherSettingsView()
        .inRootView()
        .frame(width: 600, height: 520)
}
