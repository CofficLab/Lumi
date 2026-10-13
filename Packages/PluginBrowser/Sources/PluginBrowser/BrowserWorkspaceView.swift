import SwiftUI

@MainActor
struct BrowserWorkspaceView: View {
    @ObservedObject var manager: BrowserSessionManager

    var body: some View {
        Group {
            if let session = manager.activeSession {
                BrowserPageView(session: session, manager: manager)
            } else {
                BrowserEmptyView(manager: manager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private struct BrowserPageView: View {
    @ObservedObject var session: BrowserSession
    let manager: BrowserSessionManager
    @State private var address = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { session.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!session.canGoBack)
                .help("Back")

                Button { session.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!session.canGoForward)
                .help("Forward")

                Button {
                    if session.isLoading { session.stop() } else { session.reload() }
                } label: {
                    Image(systemName: session.isLoading ? "xmark" : "arrow.clockwise")
                }
                .help(session.isLoading ? "Stop loading" : "Reload")

                TextField("Search or enter website name", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { manager.navigateAddressBar(address) }
                    .accessibilityLabel("Website address")

                if session.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()
            BrowserWebView(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { address = session.urlString }
        .onReceive(session.$urlString) { value in
            if !value.isEmpty { address = value }
        }
    }
}

@MainActor
private struct BrowserEmptyView: View {
    let manager: BrowserSessionManager
    @State private var address = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
            Text("Browser")
                .font(.title2.weight(.semibold))
            Text("Ask Lumi to open a page, or enter a website address.")
                .foregroundStyle(.secondary)
            HStack {
                TextField("https://example.com", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { manager.navigateAddressBar(address) }
                Button("Open") { manager.navigateAddressBar(address) }
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
