import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct ErrorTransportDetailsButton: View {
    @LumiTheme private var theme

    let details: ResolvedErrorTransportDetails
    @State private var isPresented = false

    var body: some View {
        AppIconButton(
            systemImage: "network",
            tint: isPresented ? theme.textPrimary : theme.textSecondary,
            size: .regular,
            isActive: isPresented
        ) {
            isPresented.toggle()
        }
        .help(LumiPluginLocalization.string("Show request and response details", bundle: .module))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ErrorTransportDetailsPopoverContent(details: details)
        }
    }
}

private struct ErrorTransportDetailsPopoverContent: View {
    @LumiTheme private var theme

    private enum DetailsTab: Hashable {
        case request
        case response
    }

    let details: ResolvedErrorTransportDetails
    @State private var selectedTab: DetailsTab = .request

    private var currentTabContent: String {
        switch selectedTab {
        case .request:
            details.requestDetails ?? "-"
        case .response:
            details.responseDetails ?? "-"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LumiPluginLocalization.string("Request / Response Details", bundle: .module))
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

            Picker("", selection: $selectedTab) {
                Text(LumiPluginLocalization.string("Sending Data", bundle: .module)).tag(DetailsTab.request)
                Text(LumiPluginLocalization.string("Received Data", bundle: .module)).tag(DetailsTab.response)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

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
