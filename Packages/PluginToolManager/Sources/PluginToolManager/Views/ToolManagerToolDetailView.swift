import KitAgentTool
import LumiUI
import SwiftUI

/// 工具详情（主从布局的右栏）：选中工具的归属、执行方式与输入参数。
///
/// 头部是工具名 + 描述 + 归属插件，下方是「概览」与「输入参数」两张原生卡片。
struct ToolManagerToolDetailView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        Group {
            if let entry = viewModel.selectedTool {
                detail(entry)
            } else {
                AppEmptyState(
                    icon: "wrench.and.screwdriver",
                    title: L("Select a tool"),
                    description: L("Choose a tool from the list to inspect its description and input schema.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Detail

    private func detail(_ entry: ToolManagerViewModel.ToolEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(entry)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 12)
            AppDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppSettingSection(title: L("Overview"), titleAlignment: .leading) {
                        VStack(spacing: 0) {
                            AppSettingRow(title: L("Tool"), icon: "wrench.and.screwdriver") {
                                Text(entry.tool.name)
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Divider()
                                .padding(.vertical, 8)
                            AppSettingRow(title: L("Plugin"), icon: "puzzlepiece.extension") {
                                Text(entry.pluginID)
                                    .font(.appMonoCaption)
                                    .foregroundStyle(theme.textSecondary)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Divider()
                                .padding(.vertical, 8)
                            AppSettingRow(title: L("Execution"), icon: "arrow.triangle.2.circlepath") {
                                Text(executionDescription(for: entry.tool.executionCapability))
                                    .font(.appCaption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }

                    AppSettingSection(title: L("Input Schema"), titleAlignment: .leading) {
                        Text(schemaText(for: entry.tool))
                            .font(.appMonoCaption)
                            .foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(12)
                            .background(
                                theme.surface.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
    }

    // MARK: - Header

    private func header(_ entry: ToolManagerViewModel.ToolEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appTitle)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    theme.textSecondary.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.tool.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(entry.tool.description(for: .current))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.pluginID)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    /// 工具的执行方式：串行（有副作用）、并行（只读）还是交互式（阻塞回合）。
    private func executionDescription(for capability: ToolExecutionCapability) -> String {
        switch capability {
        case .serialSideEffect: L("Serial")
        case .parallelReadOnly: L("Parallel (read-only)")
        case .interactive: L("Interactive")
        }
    }

    /// 输入参数的 JSON Schema（格式化输出）。
    private func schemaText(for tool: any SuperAgentTool) -> String {
        let schema = tool.inputSchema(for: .current)
        guard JSONSerialization.isValidJSONObject(schema),
              let data = try? JSONSerialization.data(
                withJSONObject: schema,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: schema)
        }
        return text
    }
}
