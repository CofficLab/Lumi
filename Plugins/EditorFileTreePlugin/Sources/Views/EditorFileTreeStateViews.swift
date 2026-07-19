import SwiftUI
import LumiKernel

/// 文件树加载状态视图
public struct EditorFileTreeLoadingView: View {
    public let depth: Int

    public init(depth: Int = 0) {
        self.depth = depth
    }

    public var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.6)
            Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                .font(.system(size: 10))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(depth) * 16 + 24)
        .padding(.vertical, 4)
    }
}

/// 文件树空目录视图
public struct EditorFileTreeEmptyView: View {
    public let depth: Int

    public init(depth: Int = 0) {
        self.depth = depth
    }

    public var body: some View {
        Text(LumiPluginLocalization.string("Empty folder", bundle: .module))
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
        NoProjectView()
    }
    .frame(width: 200)
}
