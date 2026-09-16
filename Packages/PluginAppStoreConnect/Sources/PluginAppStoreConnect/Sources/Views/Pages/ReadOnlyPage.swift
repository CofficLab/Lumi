import LumiUI
import SwiftUI

struct ReadOnlyPage: View {
    @ObservedObject var viewModel: VM
    let version: AppStoreVersion

    var body: some View {
        VStack(spacing: 0) {
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
