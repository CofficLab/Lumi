import MagicKit
import SwiftUI

/// 头部左侧视图：应用图标、当前项目名
struct ChatHeaderLeadingView: View {
    @EnvironmentObject var projectVM: ProjectVM

    @State private var isProjectSelectorPresented = false

    private let iconSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !projectVM.currentProjectPath.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: iconSize))
                        .foregroundColor(.accentColor)
                        .padding(4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())

                    Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                        .font(DesignTokens.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
            }
        }
        .popover(isPresented: $isProjectSelectorPresented, arrowEdge: .top) {
            ProjectSelectorView(isPresented: $isProjectSelectorPresented)
                .frame(width: 400, height: 500)
        }
        .onOpenProjectSelector {
            isProjectSelectorPresented = true
        }
    }
}
