import MagicKit
import SwiftUI

/// 头部左侧视图：应用图标、当前项目名、未选项目时的提示条
struct ChatHeaderLeadingView: View {
    @EnvironmentObject var agentProvider: AgentVM
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

            if projectVM.currentProjectPath.isEmpty {
                projectSelectionHint
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

    private var projectSelectionHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))

            Text("请选择一个项目以开始")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Spacer()

            Button(action: {
                isProjectSelectorPresented = true
            }) {
                Text("选择项目")
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
