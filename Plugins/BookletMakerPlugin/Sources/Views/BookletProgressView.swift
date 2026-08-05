import SwiftUI

// MARK: - Booklet Progress View

/// Progress bar + status text, shown while a render is in flight.
struct BookletProgressView: View {

    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if viewModel.isRendering {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                } else if viewModel.lastOutputURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(BookletLocalization.string("Export complete"))
                        .font(.subheadline)
                    Spacer()
                    Button(BookletLocalization.string("Show in Finder")) {
                        if let url = viewModel.lastOutputURL {
                            viewModel.revealInFinder(url)
                        }
                    }
                    .buttonStyle(.borderless)
                } else if let error = viewModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Text(BookletLocalization.string("Ready"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            if viewModel.isRendering {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
