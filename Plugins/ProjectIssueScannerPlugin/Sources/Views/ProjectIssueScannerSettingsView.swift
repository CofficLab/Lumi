import LumiUI
import SwiftUI
import LumiKernel

/// 项目问题扫描器设置视图
///
/// 在插件设置中显示模型选择配置。
public struct ProjectIssueScannerSettingsView: View {
    @State private var modelPreference: ScannerModelPreference = ScannerModelPreference.load()

    public var body: some View {
        PluginSettingsScaffold(
            title: "Project Issue Scanner 设置",
            subtitle: "选择用于深度分析的 LLM 模型。自动模式将根据可用性和成本自动选择最优模型。",
            showHeader: false
        ) {
            AppCard {
                AppSettingsSection(
                    title: "LLM 模型选择",
                    subtitle: "选择用于深度分析的 LLM 模型。自动模式将根据可用性和成本自动选择最优模型。",
                    spacing: 12
                ) {
                    ScannerModelPickerView(preference: $modelPreference)
                }
            }

            AppCard {
                AppSettingsSection(title: "说明", spacing: 6) {
                    AppSettingsRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: LumiPluginLocalization.string("• Auto：自动从所有可用模型中选择最优的", bundle: .module))
                            Text(verbatim: LumiPluginLocalization.string("• 手动指定：固定使用某个供应商的特定模型", bundle: .module))
                            Text(verbatim: LumiPluginLocalization.string("• 每日最多执行 5 次深度分析（节省成本）", bundle: .module))
                        }
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: modelPreference) { _, newPreference in
            newPreference.save()
            Task {
                await DeepIssueAnalyzer.shared.updateModelPreference(newPreference)
            }
        }
    }
}
