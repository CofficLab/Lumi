import LumiUI
import SwiftUI

struct EditablePage: View {
    @ObservedObject var viewModel: VM
    let version: AppStoreVersion
    @Binding var importingScreenshots: Bool

    var body: some View {
        VStack(spacing: 12) {
            VersionStatusBanner(
                version: version,
                viewModel: viewModel,
                localePickerSourceView: "EditableVersionPage.localePicker"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenshotsSection(
                        viewModel: viewModel,
                        importingScreenshots: $importingScreenshots,
                        isEditable: true
                    )

                    MetadataSection(viewModel: viewModel)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
