import SwiftUI

/// 设计师面板顶部的小型 scope 标识徽章（In Project / In App）。
struct IconDesignerScopeBadge: View {
    let scope: IconScope

    init(scope: IconScope) {
        self.scope = scope
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope == .project ? "folder" : "app.badge")
                .font(.caption2)
            Text(scope.displayName())
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        IconDesignerScopeBadge(scope: .project)
        IconDesignerScopeBadge(scope: .app)
    }
    .padding()
}
