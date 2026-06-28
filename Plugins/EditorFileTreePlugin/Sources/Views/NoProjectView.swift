import SwiftUI
import LumiCoreKit

/// 文件树无项目视图（未选择项目）
public struct NoProjectView: View {
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(LumiPluginLocalization.string("No project", bundle: .module))
                .font(.system(size: 11))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NoProjectView()
        .frame(width: 200, height: 300)
}
