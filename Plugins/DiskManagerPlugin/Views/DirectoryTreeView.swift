import SwiftUI

struct DirectoryTreeView: View {
    let entries: [DirectoryEntry]
    
    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("无数据", systemImage: "folder", description: Text("扫描后将显示目录结构"))
        } else {
            List(entries, children: \.children) { entry in
                HStack {
                    Image(nsImage: entry.icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                    
                    Text(entry.name)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 简单的进度条表示相对大小（可选，暂不实现）
                    
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
