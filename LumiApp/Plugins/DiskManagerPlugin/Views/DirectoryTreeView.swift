import SwiftUI

struct DirectoryTreeView: View {
    let entries: [DirectoryEntry]
    
    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No Data", systemImage: "folder", description: Text("Directory structure will be displayed after scanning"))
        } else {
            List(entries, children: \.children) { entry in
                HStack {
                    Image(nsImage: entry.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                    
                    Text(entry.name)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Simple progress bar for relative size (optional, not implemented yet)
                    
                    Text(formatBytes(entry.size))
                        .font(.monospacedDigit(.caption)())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
