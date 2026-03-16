import SwiftUI
import MagicAlert

/// 自动批准开关：控制是否自动批准高风险命令
struct AutoApproveToggle: View {
    @EnvironmentObject var ProjectVM: ProjectVM

    var body: some View {
        HStack(spacing: 6) {
            Text("Auto")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Toggle("", isOn: Binding(
                get: { ProjectVM.autoApproveRisk },
                set: { newValue in
                    ProjectVM.setAutoApproveRisk(newValue)
                    let message = newValue
                        ? "已开启自动批准高风险命令"
                        : "已关闭自动批准高风险命令"
                    alert_info(message)
                }
            ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(6)
        .help("自动批准高风险命令")
    }
}

#Preview("Auto Approve Toggle") {
    AutoApproveToggle()
        .padding()
        .background(Color.black)
        .inRootView()
}
