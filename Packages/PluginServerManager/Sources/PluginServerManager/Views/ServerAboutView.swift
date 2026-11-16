import SwiftUI

/// Docs「关于」页。
struct ServerAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(ServerManagerLocalization.string("Server Manager"), systemImage: "server.rack")
                .font(.title2.weight(.semibold))
            Text(ServerManagerLocalization.string("Manage remote servers over SSH."))
                .foregroundStyle(.secondary)
            Text(ServerManagerLocalization.string("about.body"))
                .font(.callout)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}