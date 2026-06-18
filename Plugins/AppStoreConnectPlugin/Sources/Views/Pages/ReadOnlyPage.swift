import LumiUI
import SwiftUI

struct ReadOnlyPage: View {
    @ObservedObject var viewModel: ConnectViewModel
    let version: AppStoreVersion

    var body: some View {
        VStack(spacing: 12) {
            VersionStatusBanner(
                version: version,
                viewModel: viewModel,
                localePickerSourceView: "ReadOnlyPage.localePicker"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenshotsSection(
                        viewModel: viewModel,
                        importingScreenshots: .constant(false),
                        isEditable: false
                    )

                    MetadataDisplaySection(localization: viewModel.selectedLocalization)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
