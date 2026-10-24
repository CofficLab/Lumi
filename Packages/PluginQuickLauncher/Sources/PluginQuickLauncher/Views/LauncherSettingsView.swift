import AppKit
import Carbon.HIToolbox
import LumiUI
import SwiftUI

/// 启动器设置页：全局热键录制 + 内容源开关。
///
/// 只依赖 `QuickLauncherSettingsViewModel`；热键、录制与持久化配置
/// 全部由 ViewModel 提供。
public struct LauncherSettingsView: View {
    @ObservedObject private var viewModel: QuickLauncherSettingsViewModel

    init(viewModel: QuickLauncherSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                hotkeySection
                sourcesSection
                usageSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onDisappear {
            viewModel.stopRecording()
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        AppSettingSection(
            title: pluginLocalization.string("Global Hotkey"),
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: pluginLocalization.string("Toggle Launcher"),
                description: pluginLocalization.string("Press the hotkey anywhere to open the launcher. Click Record, then press a key combination with ⌘/⌥/⌃."),
                icon: "command"
            ) {
                HStack(spacing: 8) {
                    AppTag(viewModel.currentComboDisplay, systemImage: "command", style: .accent)

                    if viewModel.isRecording {
                        AppButton(
                            pluginLocalization.string("Cancel"),
                            systemImage: "xmark",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.stopRecording()
                        }
                    } else {
                        AppButton(
                            pluginLocalization.string("Record"),
                            systemImage: "record.circle",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.startRecording()
                        }
                        AppButton(
                            pluginLocalization.string("Reset"),
                            systemImage: "arrow.counterclockwise",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.resetHotkey()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("Search Sources"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingToggleRow(
                    pluginLocalization.string("Applications"),
                    icon: "app.fill",
                    isOn: $viewModel.appsEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    pluginLocalization.string("Files (Spotlight)"),
                    icon: "doc.text.magnifyingglass",
                    isOn: $viewModel.filesEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    pluginLocalization.string("Commands"),
                    icon: "terminal",
                    isOn: $viewModel.commandsEnabled
                )
            }
        }
    }

    // MARK: - Usage

    private var usageSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("How to Use"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                instructionRow(
                    key: viewModel.currentComboDisplay,
                    description: pluginLocalization.string("Open the launcher anywhere"),
                    icon: "command"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "?",
                    description: pluginLocalization.string("Prefix with ? to ask Lumi directly"),
                    icon: "questionmark"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "↑ ↓",
                    description: pluginLocalization.string("Navigate results"),
                    icon: "arrow.up.arrow.down"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "↩",
                    description: pluginLocalization.string("Open / execute selected result"),
                    icon: "return"
                )
                Divider()
                    .padding(.vertical, 8)
                instructionRow(
                    key: "Esc",
                    description: pluginLocalization.string("Close the launcher"),
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
}

#Preview("Launcher Settings") {
    LauncherSettingsView(viewModel: QuickLauncherSettingsViewModel(hotkeyManager: .shared))
        .inRootView()
        .frame(width: 600, height: 520)
}
