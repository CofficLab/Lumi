import LumiUI
import SwiftUI

/// 右侧 Inspector 内容容器。
///
/// Phase 0 仅提供骨架：展示当前连接与选中对象的基本信息，以及后续将入驻的功能入口。
/// 后续 Phase 会在 `body` 里按 `inspectorSection` 分区填充结构详情 / ER / EXPLAIN。
public struct DatabaseInspectorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: DatabaseViewModel

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                connectionSection
                if viewModel.selectedSQLiteTable != nil || viewModel.queryResult != nil {
                    selectionSection
                }
                roadmapSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.surface)
    }

    @ViewBuilder
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Connection", systemImage: "cylinder.split.1x2")
            if let config = viewModel.selectedConfig {
                AppCard {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledRow(label: "Name", value: config.name)
                        LabeledRow(label: "Type", value: config.type.rawValue)
                        if let host = config.host {
                            LabeledRow(label: "Host", value: "\(host)\(config.port.map { ":\($0)" } ?? "")")
                        }
                        LabeledRow(label: "Database", value: config.database)
                        LabeledRow(
                            label: "SSL",
                            value: config.type.capabilities.supportsSSL ? "Supported" : "N/A"
                        )
                    }
                }
            } else {
                AppEmptyState(
                    icon: "cylinder.split.1x2",
                    title: LumiPluginLocalization.string("No database connected", bundle: .module),
                    description: LumiPluginLocalization.string("Connect from the sidebar.", bundle: .module)
                )
            }
        }
    }

    @ViewBuilder
    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Selection", systemImage: "hand.tap")
            if let table = viewModel.selectedSQLiteTable {
                AppCard {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledRow(label: "Table", value: table)
                        if let result = viewModel.queryResult {
                            LabeledRow(label: "Columns", value: "\(result.columns.count)")
                            LabeledRow(label: "Rows", value: "\(result.rows.count)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Roadmap", systemImage: "map")
            AppCard {
                VStack(alignment: .leading, spacing: 6) {
                    RoadmapRow(label: "Structure details", phase: "Phase 5")
                    RoadmapRow(label: "EXPLAIN visualization", phase: "Phase 4")
                    RoadmapRow(label: "ER diagram", phase: "Phase 6")
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.appMicro)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.appMicroEmphasized)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct RoadmapRow: View {
    let label: String
    let phase: String

    var body: some View {
        HStack {
            Text(label)
                .font(.appMicro)
                .foregroundStyle(.secondary)
            Spacer()
            AppTag(phase, systemImage: nil, style: .subtle)
        }
    }
}
