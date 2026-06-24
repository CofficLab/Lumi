import LumiCoreKit
import LumiUI
import SwiftUI

private enum ErrorMessageLayoutConstants {
    static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"
}

struct ErrorMessageLayout<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool
    @ViewBuilder let content: () -> Content

    private var copyContent: String {
        if !message.content.isEmpty {
            return message.content
        }
        return message.rawErrorDetail ?? ""
    }

    private var hasTransportDetails: Bool {
        copyContent.contains(ErrorMessageLayoutConstants.transportDetailsSeparator)
    }

    private var popoverContent: String {
        if hasTransportDetails {
            let parts = copyContent.components(separatedBy: ErrorMessageLayoutConstants.transportDetailsSeparator)
            return parts.count > 1 ? parts[1] : copyContent
        }
        if !copyContent.isEmpty {
            return copyContent
        }
        return message.renderKind ?? ""
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
                        content: popoverContent,
                        hasTransportDetails: hasTransportDetails
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

    private struct ParsedDetails {
        let request: String
        let response: String
    }

    let title: String
    let content: String
    let hasTransportDetails: Bool

    @State private var selectedTab: DetailsTab = .request
    @State private var parsed: ParsedDetails?

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

            if let parsed {
                ScrollView {
                    Text(selectedTab == .request ? parsed.request : parsed.response)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(LumiPluginLocalization.string("Parsing details...", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
        .frame(width: 680)
        .frame(minHeight: 520)
        .frame(maxHeight: 760)
        .task(id: content) {
            guard parsed == nil else { return }
            let payload = content
            let includeTabs = hasTransportDetails
            let parsedDetails = await Task.detached(priority: .userInitiated) {
                Self.parseDetails(content: payload, hasTransportDetails: includeTabs)
            }.value
            parsed = parsedDetails
        }
    }

    private var currentTabContent: String {
        guard let parsed else { return content }
        return selectedTab == .request ? parsed.request : parsed.response
    }

    nonisolated private static func parseDetails(content: String, hasTransportDetails: Bool) -> ParsedDetails {
        guard hasTransportDetails else {
            return ParsedDetails(request: content, response: "-")
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var request: [String] = []
        var response: [String] = []
        var isResponseSection = false

        for line in lines {
            if line.hasPrefix("Response Status:") || line.hasPrefix("Response Headers:") || line.hasPrefix("Response Body:") {
                isResponseSection = true
            }
            if isResponseSection {
                response.append(line)
            } else {
                request.append(line)
            }
        }

        let requestText = request.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let responseText = response.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedDetails(
            request: requestText.isEmpty ? "-" : requestText,
            response: responseText.isEmpty ? "-" : responseText
        )
    }
}
