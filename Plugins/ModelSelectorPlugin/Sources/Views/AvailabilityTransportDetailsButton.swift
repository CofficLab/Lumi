import LumiCoreKit
import LumiUI
import SwiftUI

struct AvailabilityTransportDetailsTrigger: View {
    @LumiTheme private var theme

    let action: () -> Void

    var body: some View {
        AppIconButton(
            systemImage: "info.circle",
            tint: theme.textSecondary,
            size: .compact,
            action: action
        )
        .help(LumiPluginLocalization.string("Show HTTP response details", bundle: .module))
    }
}

struct AvailabilityTransportDetailsPopoverContent: View {
    let failure: LumiLLMFailureDetail

    var body: some View {
        AppHTTPResponseView(
            statusCode: failure.httpStatusCode,
            body: failure.transportDetails,
            title: LumiPluginLocalization.string("HTTP Response Details", bundle: .module)
        )
        .frame(width: 520, height: 300, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: true)
    }
}

/// Compact status label with optional HTTP details popover for availability lists.
struct AvailabilityFailureStatusLabel: View {
    @LumiTheme private var theme

    let failure: LumiLLMFailureDetail
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 4) {
            Text(failure.availabilityDisplayText)
                .font(.appCaption)
                .foregroundColor(failure.reason == .unsupportedModel ? theme.textSecondary : .red)
                .lineLimit(1)

            if failure.hasTransportDiagnostics {
                AvailabilityTransportDetailsTrigger {
                    isPresented = true
                }
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AvailabilityTransportDetailsPopoverContent(failure: failure)
        }
    }
}
