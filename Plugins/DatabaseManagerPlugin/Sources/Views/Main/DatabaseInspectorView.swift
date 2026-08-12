import AppKit
import EditorService
import EditorSource
import LumiUI
import SwiftUI

/// Connection details and read-only schema browser for the selected table.
public struct DatabaseInspectorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: DatabaseViewModel
    @State private var section: SchemaInspectorSection = .columns
    @State private var ddlText = ""
    @State private var ddlEditorState = SourceEditorState()
    @Environment(\.colorScheme) private var colorScheme

    public init(viewModel: DatabaseViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            AppDivider()
            if let object = viewModel.openTableObject {
                schemaContent(for: object)
            } else {
                connectionContent
            }
        }
        .background(theme.surface)
        .onChange(of: viewModel.openTableObject?.id) { _, _ in
            section = .columns
            ddlText = ""
        }
        .onChange(of: viewModel.selectedTableSchema?.ddl) { _, ddl in
            ddlText = ddl ?? ""
        }
    }

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.openTableObject?.kind.systemImage ?? "cylinder.split.1x2")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.openTableObject?.name ?? "Inspector")
                    .font(.appBodyEmphasized)
                    .lineLimit(1)
                Text(viewModel.openTableObject?.kind.rawValue.capitalized ?? "Connection")
                    .font(.appMicro)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.openTableObject != nil {
                AppIconButton(systemImage: "arrow.clockwise", label: "Refresh Structure", size: .compact) {
                    Task { await viewModel.loadSelectedTableSchema(refresh: true) }
                }
                .disabled(viewModel.isLoadingTableSchema)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }

    @ViewBuilder
    private func schemaContent(for object: DatabaseObject) -> some View {
        if viewModel.isLoadingTableSchema, viewModel.selectedTableSchema == nil {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading structure…")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.tableSchemaError {
            AppEmptyState(
                icon: "exclamationmark.triangle",
                title: "Unable to Load Structure",
                description: error
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let schema = viewModel.selectedTableSchema {
            VStack(spacing: 0) {
                sectionPicker(for: schema)
                AppDivider()
                ScrollView {
                    sectionContent(schema)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        } else {
            AppEmptyState(
                icon: object.kind.systemImage,
                title: "No Structure Available",
                description: "Refresh to load metadata for this object."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sectionPicker(for schema: TableSchema) -> some View {
        Picker("Structure Section", selection: $section) {
            ForEach(availableSections(for: schema)) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
    }

    @ViewBuilder
    private func sectionContent(_ schema: TableSchema) -> some View {
        switch section {
        case .columns:
            metadataList(schema.columns) { column in
                SchemaMetadataCard(
                    title: column.name,
                    subtitle: column.dataType,
                    badges: columnBadges(column),
                    details: [
                        ("Default", column.defaultValue ?? "None"),
                        ("Position", String(column.position + 1)),
                    ]
                )
            }
        case .indexes:
            metadataList(schema.indexes) { index in
                SchemaMetadataCard(
                    title: index.name,
                    subtitle: index.columns.joined(separator: ", "),
                    badges: [index.isUnique ? "UNIQUE" : "INDEX"],
                    details: [("Type", index.indexType ?? "Default")]
                )
            }
        case .foreignKeys:
            metadataList(schema.foreignKeys) { key in
                SchemaMetadataCard(
                    title: key.name,
                    subtitle: "\(key.columns.joined(separator: ", ")) → \(key.referencesTable).\(key.referencesColumns.joined(separator: ", "))",
                    badges: [],
                    details: [
                        ("On Delete", key.onDelete ?? "Default"),
                        ("On Update", key.onUpdate ?? "Default"),
                    ]
                )
            }
        case .triggers:
            metadataList(schema.triggers) { trigger in
                SchemaMetadataCard(
                    title: trigger.name,
                    subtitle: [trigger.timing, trigger.event].compactMap { $0 }.joined(separator: " "),
                    badges: [trigger.isEnabled ? "ENABLED" : "DISABLED"],
                    details: trigger.statement.map { [("Statement", $0)] } ?? []
                )
            }
        case .ddl:
            ddlContent(schema.ddl)
        }
    }

    @ViewBuilder
    private func metadataList<Item, Content: View>(
        _ items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        if items.isEmpty {
            Text("No items")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    content(item)
                }
            }
        }
    }

    @ViewBuilder
    private func ddlContent(_ ddl: String?) -> some View {
        if let ddl, !ddl.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                AppButton("Copy DDL", systemImage: "doc.on.doc", style: .ghost, size: .small) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ddl, forType: .string)
                }
                SourceEditor(
                    $ddlText,
                    language: DatabaseSQLLanguageSupport.context,
                    configuration: ddlEditorConfiguration,
                    state: $ddlEditorState
                )
                .frame(minHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .onAppear { ddlText = ddl }
        } else {
            Text("DDL is not available for this object.")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var ddlEditorConfiguration: SourceEditorConfiguration {
        let resolved = LumiUIThemeRegistry.shared.resolvedEditorSyntax(colorScheme: colorScheme)
        let palette = resolved?.palette ?? .standard(isDark: colorScheme == .dark)
        return SourceEditorConfiguration(
            appearance: .init(
                theme: EditorSyntaxPaletteAdapter.makeEditorTheme(from: palette),
                themeIdentifier: resolved?.themeId ?? "database-ddl-\(colorScheme == .dark ? "dark" : "light")",
                font: .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                wrapLines: false
            ),
            behavior: .init(isEditable: false, isSelectable: true),
            layout: .init(additionalTextInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)),
            peripherals: .init(
                showGutter: true,
                showMinimap: false,
                showReformattingGuide: false,
                showFoldingRibbon: false
            )
        )
    }

    private var connectionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let config = viewModel.selectedConfig {
                    SchemaMetadataCard(
                        title: config.name,
                        subtitle: config.type.rawValue,
                        badges: [viewModel.isConnected ? "CONNECTED" : "DISCONNECTED"],
                        details: [
                            ("Host", config.host.map { "\($0)\(config.port.map { ":\($0)" } ?? "")" } ?? "Local"),
                            ("Database", config.database),
                            ("SSL", config.type.capabilities.supportsSSL ? "Supported" : "N/A"),
                        ]
                    )
                    Text("Open a table or view to inspect its structure.")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                } else {
                    AppEmptyState(
                        icon: "cylinder.split.1x2",
                        title: "No Database Connected",
                        description: "Connect from the sidebar."
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func availableSections(for schema: TableSchema) -> [SchemaInspectorSection] {
        guard let capabilities = viewModel.selectedConfig?.type.capabilities else { return [.columns, .ddl] }
        var result: [SchemaInspectorSection] = [.columns]
        if capabilities.supportsIndexes { result.append(.indexes) }
        if capabilities.supportsForeignKeys { result.append(.foreignKeys) }
        if capabilities.supportsTriggers { result.append(.triggers) }
        if schema.ddl != nil { result.append(.ddl) }
        return result
    }

    private func columnBadges(_ column: TableColumn) -> [String] {
        var badges: [String] = []
        if column.isPrimaryKey { badges.append("PRIMARY KEY") }
        badges.append(column.isNullable ? "NULL" : "NOT NULL")
        return badges
    }
}

private enum SchemaInspectorSection: String, Identifiable, CaseIterable {
    case columns
    case indexes
    case foreignKeys
    case triggers
    case ddl

    var id: String { rawValue }
    var title: String {
        switch self {
        case .columns: "Columns"
        case .indexes: "Indexes"
        case .foreignKeys: "Foreign Keys"
        case .triggers: "Triggers"
        case .ddl: "DDL"
        }
    }
    var systemImage: String {
        switch self {
        case .columns: "rectangle.split.3x1"
        case .indexes: "list.number"
        case .foreignKeys: "link"
        case .triggers: "bolt"
        case .ddl: "doc.plaintext"
        }
    }
}

private struct SchemaMetadataCard: View {
    let title: String
    let subtitle: String
    let badges: [String]
    let details: [(String, String)]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.appMicroEmphasized)
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    ForEach(badges, id: \.self) { badge in
                        AppTag(badge, systemImage: nil, style: .subtle)
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appMicro)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    HStack(alignment: .firstTextBaseline) {
                        Text(detail.0)
                            .font(.appMicro)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(detail.1)
                            .font(.appMicroEmphasized)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
