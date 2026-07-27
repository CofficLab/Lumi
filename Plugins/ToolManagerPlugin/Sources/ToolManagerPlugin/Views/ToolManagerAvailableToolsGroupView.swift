import LumiKernel
import LumiUI
import SwiftUI

/// 状态栏可用工具分组视图
struct ToolManagerAvailableToolsGroupView: View {
    @LumiTheme private var theme
    let title: String
    let toolCount: Int
    let tools: [any LumiAgentTool]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text("\(toolCount)")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 16)

            LazyVStack(spacing: 4) {
                ForEach(tools, id: \.name) { tool in
                    AppListRow {
                        HStack(spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.appCaptionEmphasized)
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.textTertiary.opacity(0.12))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.name)
                                    .font(.appCaptionEmphasized)
                                    .foregroundColor(theme.textPrimary)
                                Text(tool.toolDescription)
                                    .font(.appMicro)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}
