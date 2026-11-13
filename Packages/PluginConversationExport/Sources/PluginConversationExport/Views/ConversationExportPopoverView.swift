import SwiftUI

/// 导出入口弹层：按场景选择导出内容，选中后立即开始导出。
struct ConversationExportPopoverView: View {
    let onSelect: (ConversationExportMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pluginLocalization.string("Export Conversation"))
                    .font(.system(size: 12, weight: .semibold))
                Text(pluginLocalization.string("Choose how this conversation should be exported."))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            modeButton(
                mode: .debug,
                icon: "wrench.and.screwdriver",
                title: pluginLocalization.string("Development & Debugging"),
                detail: pluginLocalization.string("Keeps tool calls, reasoning, IDs, and paths for troubleshooting.")
            )
            modeButton(
                mode: .share,
                icon: "person.2",
                title: pluginLocalization.string("Share Conversation"),
                detail: pluginLocalization.string("A clean transcript without tool calls, reasoning, or technical metadata.")
            )
        }
        .padding(10)
        .frame(width: 300)
    }

    private func modeButton(
        mode: ConversationExportMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            onSelect(mode)
        } label: {
            ConversationExportModeRow(icon: icon, title: title, detail: detail)
        }
        .buttonStyle(.plain)
    }
}

private struct ConversationExportModeRow: View {
    let icon: String
    let title: String
    let detail: String

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            isHovered ? Color.accentColor.opacity(0.10) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovered = $0 }
    }
}
