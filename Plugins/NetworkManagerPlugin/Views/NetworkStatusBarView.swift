import SwiftUI

struct NetworkStatusBarView: View {
    @ObservedObject var networkService = NetworkService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Upload
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .bold))
                Text(formatSpeed(networkService.uploadSpeed))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(minWidth: 45, alignment: .leading)
            }
            
            // Download
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(formatSpeed(networkService.downloadSpeed))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(minWidth: 45, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        // Ensure fixed height for menu bar
        .frame(height: 22) 
    }
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        let kb = bytesPerSec / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1.0 {
            return String(format: "%.1f GB/s", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB/s", mb)
        } else {
            return String(format: "%.0f KB/s", kb)
        }
    }
}
