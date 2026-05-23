import SwiftUI

/// 项目问题扫描器设置视图
///
/// 在插件设置中显示模型选择配置。
struct ProjectIssueScannerSettingsView: View {
    @EnvironmentObject private var llmVM: AppLLMVM

    @State private var modelPreference: ScannerModelPreference = ScannerModelPreference.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("Project Issue Scanner 设置")
                .font(.headline)

            Divider()

            // 模型选择
            VStack(alignment: .leading, spacing: 8) {
                Text("LLM 模型选择")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("选择用于深度分析的 LLM 模型。自动模式将根据可用性和成本自动选择最优模型。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScannerModelPickerView(preference: $modelPreference)
            }

            Divider()

            // 说明
            VStack(alignment: .leading, spacing: 4) {
                Text("说明")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text("• **Auto**：自动从所有可用模型中选择最优的")
                    Text("• **手动指定**：固定使用某个供应商的特定模型")
                    Text("• 每日最多执行 5 次深度分析（节省成本）")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: modelPreference) { _, newPreference in
            newPreference.save()
            Task {
                await DeepIssueAnalyzer.shared.updateModelPreference(newPreference)
            }
        }
    }
}
