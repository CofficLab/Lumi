import LumiUI
import SwiftUI

/// 侧边栏预览视图，显示右键菜单的实时预览
public struct RClickRailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject private var viewModel: RClickSettingsViewModel

    init(viewModel: RClickSettingsViewModel) {
        self.viewModel = viewModel
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

                            RClickPreviewView(config: viewModel.config)
                        }

                        // 新建文件子菜单展开预览（仅在新建文件启用且有模板时显示）
                        if viewModel.shouldShowNewFilePreview {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LumiPluginLocalization.string("New File Submenu", bundle: .module))
                                    .font(.appCaptionEmphasized)
                                    .foregroundColor(theme.textSecondary)

                                RClickNewFilePreviewView(config: viewModel.config)
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
    RClickRailView(viewModel: RClickSettingsViewModel(configManager: RClickConfigManager.shared))
        .frame(width: 240, height: 500)
        .inRootView()
}
