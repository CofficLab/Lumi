import SwiftUI

struct AvailableToolsListSheetView: View {
    let tools: [AgentTool]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredTools: [AgentTool] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tools.sorted { $0.name < $1.name } }
        return tools
            .filter { $0.name.localizedCaseInsensitiveContains(q) || $0.description.localizedCaseInsensitiveContains(q) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Tools", table: "AgentAvailableToolsHeader"))
                    .font(DesignTokens.Typography.title3)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld tools available", table: "AgentAvailableToolsHeader", comment: "Count of available tools"),
                        Int64(tools.count)
                    )
                )
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            TextField(String(localized: "Search tools", table: "AgentAvailableToolsHeader"), text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Button(String(localized: "Done", table: "AgentAvailableToolsHeader")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var content: some View {
        List {
            if filteredTools.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "No tools found", table: "AgentAvailableToolsHeader"))
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Text(String(localized: "Try a different search keyword.", table: "AgentAvailableToolsHeader"))
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .padding(.vertical, 10)
            } else {
                ForEach(Array(filteredTools.enumerated()), id: \.offset) { _, tool in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(tool.name)
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                .textSelection(.enabled)

                            Spacer()
                        }

                        if !tool.description.isEmpty {
                            Text(tool.description)
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.inset)
    }
}
