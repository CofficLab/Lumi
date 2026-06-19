import LumiUI
import SwiftUI

struct CreateVersionSheet: View {
    @ObservedObject var viewModel: VM
    @Binding var isPresented: Bool

    @State private var versionString = ""
    @State private var platform = "IOS"
    @State private var releaseType = "AFTER_APPROVAL"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStoreConnectLocalization.string("New Version"))
                .font(.title3.weight(.semibold))

            Text(AppStoreConnectLocalization.string("Create a new App Store version for the selected app."))
                .font(.caption)
                .foregroundStyle(.secondary)

            GlassTextField(
                title: AppStoreConnectLocalization.string("Version Number"),
                text: $versionString
            )

            Picker(AppStoreConnectLocalization.string("Platform"), selection: $platform) {
                ForEach(viewModel.availablePlatformsForVersionCreate(), id: \.self) { candidate in
                    Text(AppStoreVersion.platformDisplayName(candidate))
                        .tag(candidate)
                }
            }
            .onChange(of: platform) { _, newPlatform in
                versionString = viewModel.suggestedVersionString(for: newPlatform)
            }

            if !viewModel.isPlatformAvailableForVersionCreate(platform) {
                Text(AppStoreConnectLocalization.string(
                    "A version is already in progress for %@.",
                    AppStoreVersion.platformDisplayName(platform)
                ))
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Picker(AppStoreConnectLocalization.string("Release Type"), selection: $releaseType) {
                Text(AppStoreConnectLocalization.string("After Approval"))
                    .tag("AFTER_APPROVAL")
                Text(AppStoreConnectLocalization.string("Manual Release"))
                    .tag("MANUAL")
            }

            Text(AppStoreConnectLocalization.string("The new version will start in Prepare for Submission."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            HStack {
                Spacer()
                AppButton(AppStoreConnectLocalization.string("Cancel"), style: .secondary) {
                    isPresented = false
                }
                AppButton(AppStoreConnectLocalization.string("Create"), systemImage: "plus", style: .primary) {
                    Task {
                        let success = await viewModel.createVersion(
                            versionString: versionString,
                            platform: platform,
                            releaseType: releaseType
                        )
                        if success {
                            isPresented = false
                        }
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 420)
        .task {
            await viewModel.prepareCreateVersionForm()
            resetForm()
        }
        .onChange(of: viewModel.versions) { _, _ in
            versionString = viewModel.suggestedVersionString(for: platform)
        }
    }

    private var canSubmit: Bool {
        !viewModel.isBusy
            && !versionString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.isPlatformAvailableForVersionCreate(platform)
    }

    private func resetForm() {
        let platforms = viewModel.availablePlatformsForVersionCreate()
        let defaultPlatform = platforms.first(where: { viewModel.isPlatformAvailableForVersionCreate($0) })
            ?? platforms.first
            ?? "IOS"
        platform = defaultPlatform
        versionString = viewModel.suggestedVersionString(for: platform)
        releaseType = "AFTER_APPROVAL"
    }
}
