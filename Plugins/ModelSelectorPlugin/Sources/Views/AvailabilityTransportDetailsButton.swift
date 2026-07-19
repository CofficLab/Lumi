import LumiKernel
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
