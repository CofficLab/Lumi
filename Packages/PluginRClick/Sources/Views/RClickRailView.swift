import LumiUI
import SwiftUI

/// 侧边栏预览视图，显示右键菜单的实时预览
public struct RClickRailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject private var configManager: RClickConfigManager

    init(configManager: RClickConfigManager) {
        self.configManager = configManager
    }

    /// 是否显示新建文件子菜单预览
    private var shouldShowNewFilePreview: Bool {
        let config = configManager.config
        let isNewFileEnabled = config.items.contains { $0.type == .newFile && $0.isEnabled }
        let hasEnabledTemplates = config.fileTemplates.contains { $0.isEnabled }
        return isNewFileEnabled && hasEnabledTemplates
    }

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
            
            VStack {
                
                Spacer()
                
                // 预览内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 主菜单预览
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LumiPluginLocalization.string("Menu", bundle: .module))
                                .font(.appCaptionEmphasized)
                                .foregroundColor(theme.textSecondary)

                            RClickPreviewView(config: configManager.config)
                        }

                        // 新建文件子菜单展开预览（仅在新建文件启用且有模板时显示）
                        if shouldShowNewFilePreview {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LumiPluginLocalization.string("New File Submenu", bundle: .module))
                                    .font(.appCaptionEmphasized)
                                    .foregroundColor(theme.textSecondary)

                                RClickNewFilePreviewView(config: configManager.config)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview("Rail") {
    RClickRailView(configManager: RClickConfigManager.shared)
        .frame(width: 240, height: 500)
        .inRootView()
}
