import SwiftUI
import LumiUI

/// 侧边栏预览视图，显示右键菜单的实时预览
public struct RClickRailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @StateObject private var configManager = RClickConfigManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            AppToolbarContainer {
                HStack {
                    Text(LumiPluginLocalization.string("Preview", bundle: .module))
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
            }

            AppDivider()

            // 预览内容
            ScrollView {
                VStack(spacing: 16) {
                    RClickPreviewView(config: configManager.config)
                        .shadowLg()

                    // 状态统计
                    AppCard {
                        AppSettingsSection(title: LumiPluginLocalization.string("Status", bundle: .module), spacing: 8) {
                            let enabledActions = configManager.config.items.filter { $0.isEnabled && $0.type != .newFile }.count

                            AppSettingsRow {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.appCallout)
                                        .foregroundColor(theme.success)
                                    Text("\(enabledActions) \(LumiPluginLocalization.string("actions enabled", bundle: .module))")
                                        .font(.appBody)
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
                                }
                            }

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }), newFileItem.isEnabled {
                                let enabledTemplates = configManager.config.fileTemplates.filter { $0.isEnabled }.count

                                AppSettingsRow {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.appCallout)
                                            .foregroundColor(theme.info)
                                        Text("\(enabledTemplates) \(LumiPluginLocalization.string("templates enabled", bundle: .module))")
                                            .font(.appBody)
                                            .foregroundColor(theme.textSecondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview("Rail") {
    RClickRailView()
        .frame(width: 240, height: 500)
        .inRootView()
}
