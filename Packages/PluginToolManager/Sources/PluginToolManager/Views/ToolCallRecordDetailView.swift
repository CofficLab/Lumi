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

                PayloadSection(title: L("Arguments"), value: record.argumentsJSON, fallback: "{}")
                PayloadSection(title: L("Result"), value: record.resultContent, fallback: L("No result content"))
                if let resultJSON = record.resultJSON, !resultJSON.isEmpty {
                    PayloadSection(title: L("Result JSON"), value: resultJSON, fallback: "{}")
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
}

/// 大载荷的有界预览（issue #1303）。
///
/// 工具结果按原样存储，可达数 MB（shell 输出上限 16 MiB）。把整段交给一个
/// 可选中 `Text` 会让 SwiftUI 在主线程上布局全部字符，选中大记录即卡死。
/// 这里只渲染前 `limit` 个字符，默认布局与载荷总大小无关。
///
/// 计算复杂度 O(limit)：用 `prefix` 与索引比较判断是否截断，**不**调用
/// `value.count`（那会遍历整段字符串，重新引入 O(N) 主线程开销）。
struct PayloadPreview: Equatable {
    /// 实际渲染的文本（前缀）。
    let text: String
    /// 是否仍有未渲染的剩余内容。
    let isTruncated: Bool

    /// 初始渲染上限（字符）。
    static let initialLimit = 20_000
    /// 每次「显示更多」追加的上限（字符）。
    static let increment = 50_000

    static func make(_ value: String, limit: Int) -> PayloadPreview {
        let prefix = value.prefix(max(0, limit))
        return PayloadPreview(
            text: String(prefix),
            isTruncated: prefix.endIndex < value.endIndex
        )
    }
}

/// 单个载荷区块：默认只布局有界前缀，截断时提供「显示更多」逐段展开。
private struct PayloadSection: View {
    let title: String
    let value: String
    let fallback: String
    @LumiTheme private var theme
    @State private var visibleLimit = PayloadPreview.initialLimit

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        let preview = PayloadPreview.make(value.isEmpty ? fallback : value, limit: visibleLimit)
        AppSettingSection(title: title, titleAlignment: .leading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(preview.text)
                    .font(.appMonoCaption)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                if preview.isTruncated {
                    HStack(spacing: 12) {
                        Text(L("Output truncated"))
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                        AppButton(L("Show more"), systemImage: "ellipsis.circle", style: .secondary, size: .small) {
                            visibleLimit += PayloadPreview.increment
                        }
                    }
                }
            }
        }
    }
}
