import SwiftUI

/// 文件树加载状态视图
struct EditorFileTreeLoadingView: View {
    let depth: Int

    init(depth: Int = 0) {
        self.depth = depth
    }

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text(String(localized: "Loading...", table: "EditorRailFileTree"))
                .font(.system(size: 10))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(depth) * 16 + 24)
        .padding(.vertical, 4)
    }
}

/// 文件树空目录视图
struct EditorFileTreeEmptyView: View {
    let depth: Int

    init(depth: Int = 0) {
        self.depth = depth
    }

    var body: some View {
        Text(String(localized: "Empty folder", table: "EditorRailFileTree"))
            .font(.system(size: 10))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CGFloat(depth) * 16 + 24)
            .padding(.vertical, 4)
    }
}



#Preview {
    VStack(spacing: 20) {
        EditorFileTreeLoadingView()
        EditorFileTreeEmptyView()
        EditorFileTreeNoProjectView()
    }
    .frame(width: 200)
}
