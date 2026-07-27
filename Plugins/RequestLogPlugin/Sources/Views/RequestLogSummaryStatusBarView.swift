import LumiUI
import SwiftUI
import LumiKernel

struct RequestLogSummaryStatusBarView: View {
    var body: some View {
        StatusBarHoverContainer(
            detailView: RequestLogSummaryDetailView(),
            popoverWidth: 680,
            id: "chat-request-log"
        ) {
            Image(systemName: RequestLogPlugin.iconName)
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}

private struct RequestLogSummaryDetailView: View {
    @LumiTheme private var theme
    private let entries = RequestLogSummaryStore.allEntries()

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Request Log", bundle: .module),
            systemImage: RequestLogPlugin.iconName,
            subtitle: "\(entries.count) recent sends",
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.timestamp, style: .time)
                                    .font(.appCaptionEmphasized)
                                Text("Messages: \(entry.messageCount), system prompt: \(entry.systemPromptLength) chars")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
                .frame(minHeight: 280, maxHeight: 420)
            },
            footer: { EmptyView() }
        )
    }
}
