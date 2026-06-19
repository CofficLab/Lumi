import LumiUI
import SwiftUI

struct CoverArtSidebarSection: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppStoreConnectLocalization.string("Cover Art"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Button {
                viewModel.openCoverArtMaker()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.caption)
                        .frame(width: 16)
                    Text(AppStoreConnectLocalization.string("Cover Art Maker"))
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    viewModel.page == .coverArt
                        ? Color.accentColor.opacity(0.16)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }
}
