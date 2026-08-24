import LumiUI
import SwiftUI

struct AccountPage: View {
    @ObservedObject var viewModel: VM
    @Binding var showingAccountGuide: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppStoreConnectLocalization.string("Need an App Store Connect API key?"))
                                .font(.headline)
                            Text(AppStoreConnectLocalization.string("Open the setup guide for where to find Issuer ID, Key ID, and the .p8 private key."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        AppButton(AppStoreConnectLocalization.string("Setup Guide"), systemImage: "book", size: .small) {
                            showingAccountGuide = true
                        }
                    }
                }

                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStoreConnectLocalization.string("Global API Key"))
                            .font(.headline)

                        GlassTextField(title: AppStoreConnectLocalization.string("Issuer ID"), text: $viewModel.credentials.issuerID)
                        GlassTextField(title: AppStoreConnectLocalization.string("Key ID"), text: $viewModel.credentials.keyID)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppStoreConnectLocalization.string("Private Key (.p8)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $viewModel.credentials.privateKey)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25))
                                )
                            if viewModel.hasStoredPrivateKey {
                                Text(AppStoreConnectLocalization.string("A private key is stored in Keychain. Saving replaces it."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                AppCard(style: .subtle, cornerRadius: 8, showShadow: false) {
                    HStack {
                        AppButton(AppStoreConnectLocalization.string("Save Credentials"), systemImage: "key.fill", style: .primary) {
                            viewModel.saveCredentials()
                        }

                        AppButton(AppStoreConnectLocalization.string("Test Connection"), systemImage: "network") {
                            Task { await viewModel.testConnection() }
                        }
                        .disabled(!viewModel.credentials.isComplete)

                        AppButton(AppStoreConnectLocalization.string("Disconnect"), systemImage: "xmark.circle", style: .destructive) {
                            viewModel.disconnect()
                        }

                        Spacer()
                        Text(viewModel.connectionStatus)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

struct AccountGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStoreConnectLocalization.string("App Store Connect API Key Setup"))
                        .font(.title2.weight(.semibold))
                    Text(AppStoreConnectLocalization.string("Create one user-level API key, then paste the values into the Account page."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AppIconButton(systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    guideStep(
                        number: "1",
                        title: AppStoreConnectLocalization.string("Open Users and Access"),
                        body: AppStoreConnectLocalization.string("Sign in to App Store Connect with an account that can manage API keys, then open Users and Access.")
                    )

                    guideStep(
                        number: "2",
                        title: AppStoreConnectLocalization.string("Create an API key"),
                        body: AppStoreConnectLocalization.string("Go to the Keys tab, create a new key, choose the minimum role needed for app metadata and screenshot management, then save it.")
                    )

                    guideStep(
                        number: "3",
                        title: AppStoreConnectLocalization.string("Copy Issuer ID and Key ID"),
                        body: AppStoreConnectLocalization.string("Issuer ID is shown on the Keys page. Key ID is shown next to the key you created. Paste both into Lumi.")
                    )

                    guideStep(
                        number: "4",
                        title: AppStoreConnectLocalization.string("Download the .p8 private key"),
                        body: AppStoreConnectLocalization.string("Download the private key immediately. Apple only lets you download it once. Open the .p8 file and paste the full contents into the Private Key field.")
                    )

                    guideStep(
                        number: "5",
                        title: AppStoreConnectLocalization.string("Save and test"),
                        body: AppStoreConnectLocalization.string("Click Save Credentials, then Test Connection. Lumi stores the values in Keychain and uses them to generate short-lived JWT tokens.")
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStoreConnectLocalization.string("Security notes"))
                            .font(.headline)
                        Label(AppStoreConnectLocalization.string("Use the least privileged App Store Connect role that still allows the workflow you need."), systemImage: "lock")
                        Label(AppStoreConnectLocalization.string("Do not commit the .p8 key to source control or paste it into project files."), systemImage: "exclamationmark.triangle")
                        Label(AppStoreConnectLocalization.string("If a key is exposed, revoke it in App Store Connect and create a replacement."), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.callout)

                    AppButton(AppStoreConnectLocalization.string("Open App Store Connect API Keys"), systemImage: "safari", style: .secondary) {
                        if let url = URL(string: "https://appstoreconnect.apple.com/access/integrations/api") {
                            openURL(url)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
        }
        .frame(width: 640, height: 620)
    }

    private func guideStep(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
