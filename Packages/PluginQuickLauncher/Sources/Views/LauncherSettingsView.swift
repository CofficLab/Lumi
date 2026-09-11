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
#if DEBUG
                HStack {
                    Spacer()
                    AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", style: .warning, size: .small) {
                        viewModel.openDataDirectory()
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
            viewModel.stopRecording()
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
                    AppTag(viewModel.currentComboDisplay, systemImage: "command", style: .accent)

                    if viewModel.isRecording {
                        AppButton(
                            LumiPluginLocalization.string("Cancel", bundle: .module),
                            systemImage: "xmark",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.stopRecording()
                        }
                    } else {
                        AppButton(
                            LumiPluginLocalization.string("Record", bundle: .module),
                            systemImage: "record.circle",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.startRecording()
                        }
                        AppButton(
                            LumiPluginLocalization.string("Reset", bundle: .module),
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
            title: LumiPluginLocalization.string("Search Sources", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Applications", bundle: .module),
                    icon: "app.fill",
                    isOn: $viewModel.appsEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Files (Spotlight)", bundle: .module),
                    icon: "doc.text.magnifyingglass",
                    isOn: $viewModel.filesEnabled
                )
                Divider()
                    .padding(.vertical, 8)
                AppSettingToggleRow(
                    LumiPluginLocalization.string("Commands", bundle: .module),
                    icon: "terminal",
                    isOn: $viewModel.commandsEnabled
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
                    key: viewModel.currentComboDisplay,
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
}

#Preview("Launcher Settings") {
    LauncherSettingsView(viewModel: QuickLauncherSettingsViewModel(hotkeyManager: .shared))
        .inRootView()
        .frame(width: 600, height: 520)
}
