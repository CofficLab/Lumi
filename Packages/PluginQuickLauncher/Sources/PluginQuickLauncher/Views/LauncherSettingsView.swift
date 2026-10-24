import AppKit
import Carbon.HIToolbox
import LumiUI
import SwiftUI

/// 启动器设置页：全局热键录制 + 内容源开关。
///
/// 只依赖 `QuickLauncherSettingsViewModel`；热键、录制与持久化配置
/// 全部由 ViewModel 提供。
public struct LauncherSettingsView: View {
    @LumiTheme private var theme
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
        .environment(\.appSettingsCardStyleOverride, .subtle)
        .onDisappear {
            viewModel.stopRecording()
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("Global Hotkey")
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "command")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pluginLocalization.string("Toggle Launcher"))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(pluginLocalization.string("Press the hotkey anywhere to open the launcher. Click Record, then press a key combination with ⌘/⌥/⌃."))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

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
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("Search Sources")
            ) {
                AppSettingsToggleRow(
                    pluginLocalization.string("Applications"),
                    systemImage: "app.fill",
                    isOn: $viewModel.appsEnabled
                )
                AppSettingsToggleRow(
                    pluginLocalization.string("Files (Spotlight)"),
                    systemImage: "doc.text.magnifyingglass",
                    isOn: $viewModel.filesEnabled
                )
                AppSettingsToggleRow(
                    pluginLocalization.string("Commands"),
                    systemImage: "terminal",
                    isOn: $viewModel.commandsEnabled
                )
            }
        }
    }

    // MARK: - Usage

    private var usageSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("How to Use")
            ) {
                instructionRow(
                    key: viewModel.currentComboDisplay,
                    description: pluginLocalization.string("Open the launcher anywhere"),
                    icon: "command"
                )
                instructionRow(
                    key: "?",
                    description: pluginLocalization.string("Prefix with ? to ask Lumi directly"),
                    icon: "questionmark"
                )
                instructionRow(
                    key: "↑ ↓",
                    description: pluginLocalization.string("Navigate results"),
                    icon: "arrow.up.arrow.down"
                )
                instructionRow(
                    key: "↩",
                    description: pluginLocalization.string("Open / execute selected result"),
                    icon: "return"
                )
                instructionRow(
                    key: "Esc",
                    description: pluginLocalization.string("Close the launcher"),
                    icon: "escape"
                )
            }
        }
    }

    private func instructionRow(key: String, description: String, icon: String) -> some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(description)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                AppTag(key, style: .subtle)
            }
        }
    }
}

#Preview("Launcher Settings") {
    LauncherSettingsView(viewModel: QuickLauncherSettingsViewModel(hotkeyManager: .shared))
        .inRootView()
        .frame(width: 600, height: 520)
}
