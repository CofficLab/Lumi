import SwiftUI

/// 设计师面板顶部的小型 scope 标识徽章（In Project / In App）。
struct PromoScopeBadge: View {
    let scope: Scope

    // MARK: - 初始化

    init(scope: Scope) {
        self.scope = scope
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope == .project ? "folder" : "app.badge")
                .font(.caption2)
            Text(title).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - 计算属性

    private var title: String {
        switch scope {
        case .project: PromoLocalization.string("In Project")
        case .app: PromoLocalization.string("In App")
        }
    }
}

// MARK: - 预览

#Preview {
    HStack(spacing: 8) {
        PromoScopeBadge(scope: .project)
        PromoScopeBadge(scope: .app)
    }
    .padding()
}