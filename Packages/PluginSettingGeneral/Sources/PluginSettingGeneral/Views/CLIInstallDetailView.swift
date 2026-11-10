import KitLumiCLI
import LumiUI
import SwiftUI

/// 设置窗口「通用 → 命令行工具」分组的详情视图。
///
/// 展示 `lumi` 命令的安装状态，并提供安装 / 卸载按钮。
/// 安装只写入用户可写目录，**不需要管理员权限**，也不会修改用户的
/// shell 配置；若目标目录不在 `PATH` 中，会明确提示用户自行加入。
struct CLIInstallDetailView: View {
    @StateObject private var model: CLIInstallViewModel

    init(model: CLIInstallViewModel = CLIInstallViewModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        AppSettingSection(
            title: pluginLocalization.string("Command Line Tool"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: pluginLocalization.string("Command Line Tool"),
                    description: statusDescription,
                    icon: "terminal"
                ) {
                    actionButton
                }
                if let hint = hintText {
                    Divider()
                        .padding(.vertical, 8)
                    AppSettingRow(
                        title: hint.title,
                        description: hint.detail,
                        icon: hint.icon
                    ) {
                        EmptyView()
                    }
                }
                if let lastError = model.lastError {
                    Divider()
                        .padding(.vertical, 8)
                    AppSettingRow(
                        title: String(
                            format: pluginLocalization.string("Installation failed: %@"),
                            lastError
                        ),
                        icon: "exclamationmark.triangle"
                    ) {
                        EmptyView()
                    }
                }
            }
        }
        .onAppear { model.refresh() }
    }

    // MARK: - Status

    /// 状态描述文本。
    private var statusDescription: String {
        switch model.status {
        case .checking:
            pluginLocalization.string("Checking...")
        case .notInstalled:
            pluginLocalization.string("Not Installed")
        case .installed(let path):
            String(
                format: pluginLocalization.string("Installed at %@"),
                path
            )
        case .installedNotOnPath(let path, _):
            String(
                format: pluginLocalization.string("Installed at %@"),
                path
            )
        }
    }

    /// 附加提示（PATH 提醒等）。
    private var hintText: (title: String, detail: String, icon: String)? {
        switch model.status {
        case .checking:
            nil
        case .notInstalled:
            (
                pluginLocalization.string("Command Line Tool"),
                pluginLocalization.string(
                    "Install the lumi command to open directories from the terminal."
                ),
                "info.circle"
            )
        case .installed:
            (
                pluginLocalization.string("Command Line Tool"),
                pluginLocalization.string("The lumi command is ready to use."),
                "checkmark.circle"
            )
        case .installedNotOnPath(_, let directory):
            (
                pluginLocalization.string("Command Line Tool"),
                String(
                    format: pluginLocalization.string(
                        "Add %@ to your PATH to use the command right away."
                    ),
                    directory
                ),
                "exclamationmark.circle"
            )
        }
    }

    // MARK: - Actions

    /// 安装 / 卸载按钮。
    @ViewBuilder
    private var actionButton: some View {
        if model.status.isInstalled {
            AppButton(
                pluginLocalization.string("Uninstall"),
                systemImage: "trash",
                style: .secondary,
                size: .small
            ) {
                model.uninstall()
            }
            .disabled(model.isBusy)
        } else {
            AppButton(
                pluginLocalization.string("Install"),
                systemImage: "arrow.down.circle",
                style: .secondary,
                size: .small
            ) {
                model.install()
            }
            .disabled(model.isBusy)
        }
    }
}
