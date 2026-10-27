import LumiUI
import ProviderToolManager
import SwiftUI

/// 单条工具调用记录详情（主从布局的右栏）。
struct ToolCallRecordDetailView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        Group {
            if let record = viewModel.selectedRecord {
                detail(record)
            } else {
                AppEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: L("Select a tool call"),
                    description: L("Select a record from the list to inspect its arguments and result.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Detail

    private func detail(_ record: ToolCallRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppSettingSection(title: L("Execution Details"), titleAlignment: .leading) {
                    AppMetadataCard {
                        AppMetadataRow(title: L("Tool"), systemImage: "wrench.and.screwdriver") {
                            metadataValue(record.toolDisplayName.isEmpty ? record.toolName : record.toolDisplayName)
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Status"), systemImage: record.resultIsError ? "xmark.circle" : "checkmark.circle") {
                            AppTag(
                                record.resultIsError ? L("Failed") : L("Success"),
                                systemImage: record.resultIsError ? "xmark" : "checkmark",
                                style: .accent
                            )
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Risk Level"), systemImage: "shield") {
                            metadataValue(record.riskLevel)
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Created At"), systemImage: "calendar") {
                            metadataValue(record.createdAt.formatted(date: .abbreviated, time: .standard))
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Started At"), systemImage: "play.circle") {
                            metadataValue(record.startedAt.formatted(date: .abbreviated, time: .standard))
                        }
                        if let completedAt = record.completedAt {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Completed At"), systemImage: "checkmark.circle") {
                                metadataValue(completedAt.formatted(date: .abbreviated, time: .standard))
                            }
                        }
                        if let duration = record.duration {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Duration"), systemImage: "clock") {
                                metadataValue(String(format: "%.3f s", duration))
                            }
                        }
                        AppSettingsDivider()
                        AppMetadataRow(title: L("Conversation"), systemImage: "bubble.left.and.bubble.right") {
                            metadataValue(record.conversationID.uuidString, monospace: true)
                        }
                        if let turnID = record.turnID {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Turn"), systemImage: "arrow.turn.up.right") {
                                metadataValue(turnID.uuidString, monospace: true)
                            }
                        }
                        if let toolCallID = record.toolCallID {
                            AppSettingsDivider()
                            AppMetadataRow(title: L("Tool Call ID"), systemImage: "number") {
                                metadataValue(toolCallID, monospace: true)
                            }
                        }
                    }
                }

                payloadSection(title: L("Arguments"), value: record.argumentsJSON, fallback: "{}")
                payloadSection(title: L("Result"), value: record.resultContent, fallback: L("No result content"))
                if let resultJSON = record.resultJSON, !resultJSON.isEmpty {
                    payloadSection(title: L("Result JSON"), value: resultJSON, fallback: "{}")
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.surface)
    }

    // MARK: - Helpers

    private func metadataValue(_ value: String, monospace: Bool = false) -> some View {
        Text(value.isEmpty ? "—" : value)
            .font(monospace ? .appMonoCaption : .appCaption)
            .foregroundStyle(theme.textPrimary)
            .textSelection(.enabled)
    }

    private func payloadSection(title: String, value: String, fallback: String) -> some View {
        AppSettingSection(title: title, titleAlignment: .leading) {
            Text(value.isEmpty ? fallback : value)
                .font(.appMonoCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
