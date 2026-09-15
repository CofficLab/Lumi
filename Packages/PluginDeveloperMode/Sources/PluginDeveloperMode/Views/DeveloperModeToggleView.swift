import ProviderDeveloperMode
import SwiftUI
import KitLocalization
import LumiUI

/// 开发者模式开关视图：View 只依赖 `DeveloperModeViewModel`，
/// 不直接访问 `DeveloperModeProviding`。
struct DeveloperModeToggleView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: DeveloperModeViewModel

    init(viewModel: DeveloperModeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            viewModel.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isEnabled ? "hammer.fill" : "hammer")
                Text(LumiPluginLocalization.string("DEV"))
            }
            .font(.appMicroEmphasized)
            .tracking(0.3)
            .foregroundStyle(viewModel.isEnabled ? .white : theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                viewModel.isEnabled
                    ? theme.warning
                    : theme.textSecondary.opacity(0.12),
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(
            LumiPluginLocalization.string(
                viewModel.isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
        .accessibilityLabel(LumiPluginLocalization.string("Developer mode"))
        .accessibilityValue(
            LumiPluginLocalization.string(
                viewModel.isEnabled ? "Developer mode is enabled" : "Developer mode is disabled"
            )
        )
    }
}
