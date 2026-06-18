import SwiftUI

struct IconView: View {
    let url: URL?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: min(8, size * 0.24), style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
    }

    private var fallback: some View {
        Image(systemName: "app.dashed")
            .font(.system(size: size * 0.52, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.08))
    }
}
