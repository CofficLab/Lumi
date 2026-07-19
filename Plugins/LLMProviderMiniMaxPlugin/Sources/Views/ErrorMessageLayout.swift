import LumiKernel
import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

private enum TransportDetailsKeys {
    static let request = "llm.transport.request"
    static let response = "llm.transport.response"
}

struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool
    @ViewBuilder let content: () -> Content

    private var summary: String {
        if !message.content.isEmpty {
            return message.content
        }
        return message.rawErrorDetail ?? ""
    }

    private var requestDetails: String? {
        message.metadata[TransportDetailsKeys.request]
    }

    private var responseDetails: String? {
        message.metadata[TransportDetailsKeys.response]
    }

    private var hasTransportDetails: Bool {
        requestDetails != nil || responseDetails != nil
    }

    private var copyContent: String {
        var sections: [String] = []
        if !summary.isEmpty {
            sections.append(summary)
        }
        if let requestDetails, !requestDetails.isEmpty {
            sections.append("--- Request ---\n\(requestDetails)")
        }
        if let responseDetails, !responseDetails.isEmpty {
            sections.append("--- Response ---\n\(responseDetails)")
        }
        return sections.joined(separator: "\n\n")
    }

    private var popoverTitle: String {
        hasTransportDetails
            ? LumiPluginLocalization.string("Request / Response Details", bundle: .module)
            : LumiPluginLocalization.string("Raw error details", bundle: .module)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.error)

                Text(LumiPluginLocalization.string("Error", bundle: .module))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)

                ProviderBadge()

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(copyContent, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.appMicro)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .help(LumiPluginLocalization.string("Copy", bundle: .module))

                Button {
                    showRawMessage.toggle()
                } label: {
                    Image(systemName: hasTransportDetails ? "network" : "eye")
                        .font(.appMicro)
                        .foregroundColor(showRawMessage ? theme.textPrimary : theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(
                    hasTransportDetails
                        ? LumiPluginLocalization.string("Show request and response details", bundle: .module)
                        : LumiPluginLocalization.string("Show raw error details", bundle: .module)
                )
                .popover(isPresented: $showRawMessage, arrowEdge: .bottom) {
                    ErrorDetailsPopoverContent(
                        title: popoverTitle,
                        summary: summary,
                        requestDetails: requestDetails,
                        responseDetails: responseDetails
                    )
                }
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.error.opacity(0.28))
    }
}

private struct ErrorDetailsPopoverContent: View {
    @LumiTheme private var theme

    private enum DetailsTab: Hashable {
        case request
        case response
    }

    let title: String
    let summary: String
    let requestDetails: String?
    let responseDetails: String?

    @State private var selectedTab: DetailsTab = .request

    private var hasTransportDetails: Bool {
        requestDetails != nil || responseDetails != nil
    }

    private var currentTabContent: String {
        if hasTransportDetails {
            return selectedTab == .request ? (requestDetails ?? "-") : (responseDetails ?? "-")
        }
        return summary.isEmpty ? "-" : summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentTabContent, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.appMicro)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .help(LumiPluginLocalization.string("Copy", bundle: .module))
            }

            if hasTransportDetails {
                Picker("", selection: $selectedTab) {
                    Text(LumiPluginLocalization.string("Sending Data", bundle: .module)).tag(DetailsTab.request)
                    Text(LumiPluginLocalization.string("Received Data", bundle: .module)).tag(DetailsTab.response)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            ScrollView {
                Text(currentTabContent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: 680)
        .frame(minHeight: 520)
        .frame(maxHeight: 760)
    }
}