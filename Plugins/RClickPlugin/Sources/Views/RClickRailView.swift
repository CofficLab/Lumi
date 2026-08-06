import LumiUI
import SwiftUI

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
            
            VStack {
                
                Spacer()
                
                // 预览内容
                ScrollView {
                    RClickPreviewView(config: configManager.config)
                }
                
                Spacer()
            }
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
