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
            HStack {
                Text(LumiPluginLocalization.string("Preview", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            AppDivider()

            // 预览内容
            ScrollView {
                VStack(spacing: 16) {
                    RClickPreviewView(config: configManager.config)
                        .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 4)

                    // 状态统计
                    VStack(alignment: .leading, spacing: 12) {
                        // 启用的操作数量
                        let enabledActions = configManager.config.items.filter { $0.isEnabled && $0.type != .newFile }.count
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.success)
                                .font(.appCallout)
                            Text("\(enabledActions) \(LumiPluginLocalization.string("actions enabled", bundle: .module))")
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        // 启用的模板数量
                        if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }), newFileItem.isEnabled {
                            let enabledTemplates = configManager.config.fileTemplates.filter { $0.isEnabled }.count
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(theme.info)
                                    .font(.appCallout)
                                Text("\(enabledTemplates) \(LumiPluginLocalization.string("templates enabled", bundle: .module))")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
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
