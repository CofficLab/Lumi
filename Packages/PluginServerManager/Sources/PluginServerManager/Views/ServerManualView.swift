import SwiftUI

/// Docs「说明书」页。
struct ServerManualView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(ServerManagerLocalization.string("Server Manager"))
                    .font(.title2.weight(.semibold))
                Text(ServerManagerLocalization.string("manual.connections"))
                Text(ServerManagerLocalization.string("manual.probe"))
                Text(ServerManagerLocalization.string("manual.agent"))
                Text(ServerManagerLocalization.string("manual.security"))
            }
            .font(.callout)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}