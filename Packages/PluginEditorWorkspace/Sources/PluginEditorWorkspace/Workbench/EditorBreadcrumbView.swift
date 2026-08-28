import Foundation
import SwiftUI

struct EditorBreadcrumbView: View {
    let rootURL: URL?
    let fileURL: URL

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(component)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var components: [String] {
        guard let rootURL else { return [fileURL.lastPathComponent] }
        let root = rootURL.standardizedFileURL.pathComponents
        let file = fileURL.standardizedFileURL.pathComponents
        guard file.starts(with: root) else { return [fileURL.lastPathComponent] }
        return [rootURL.lastPathComponent] + Array(file.dropFirst(root.count))
    }
}
