import SwiftUI

struct AvailableToolsListSheetView: View {
    let tools: [AgentTool]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - View

extension AvailableToolsListSheetView {
    private var header: some View {
        HStack(spacing: 12) {
            headerTitle
            Spacer()
            searchField
            doneButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Tools", table: "AgentAvailableToolsHeader"))
                .font(AppUI.Typography.title3)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Text(toolsCountText)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
    }

    private var toolsCountText: String {
        String.localizedStringWithFormat(
            String(localized: "%lld tools available", table: "AgentAvailableToolsHeader", comment: "Count of available tools"),
            Int64(tools.count)
        )
    }

    private var searchField: some View {
        TextField(String(localized: "Search tools", table: "AgentAvailableToolsHeader"), text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(width: 260)
    }

    private var doneButton: some View {
        Button(String(localized: "Done", table: "AgentAvailableToolsHeader")) {
            handleDismiss()
        }
        .keyboardShortcut(.defaultAction)
    }

    private var content: some View {
        List {
            if filteredTools.isEmpty {
                emptyStateView
            } else {
                toolRows
            }
        }
        .listStyle(.inset)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "No tools found", table: "AgentAvailableToolsHeader"))
                .font(AppUI.Typography.body)
                .foregroundColor(AppUI.Color.semantic.textPrimary)
            Text(String(localized: "Try a different search keyword.", table: "AgentAvailableToolsHeader"))
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.vertical, 10)
    }

    private var toolRows: some View {
        ForEach(Array(filteredTools.enumerated()), id: \.offset) { _, tool in
            toolRow(tool)
        }
    }

    private func toolRow(_ tool: AgentTool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(tool.name)
                    .font(AppUI.Typography.body)
                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                    .textSelection(.enabled)
                Spacer()
            }

            if !tool.description.isEmpty {
                Text(tool.description)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Computed

extension AvailableToolsListSheetView {
    private var filteredTools: [AgentTool] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tools.sorted { $0.name < $1.name } }
        return tools
            .filter { $0.name.localizedCaseInsensitiveContains(q) || $0.description.localizedCaseInsensitiveContains(q) }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Action

extension AvailableToolsListSheetView {
    func handleDismiss() {
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AvailableToolsListSheetView(tools: [])
        .frame(width: 720, height: 520)
}