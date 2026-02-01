import SwiftUI

struct NetworkStatusTile: View {
    @StateObject private var viewModel = NetworkManagerViewModel()
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.body)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                    Text(viewModel.formatSpeed(viewModel.networkState.downloadSpeed))
                        .font(.caption2)
                        .monospacedDigit()
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text(viewModel.formatSpeed(viewModel.networkState.uploadSpeed))
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .frame(width: 70, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.clear)
    }
}
