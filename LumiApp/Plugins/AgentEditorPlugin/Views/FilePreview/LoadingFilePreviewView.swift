import SwiftUI

/// 文件加载中占位视图
struct LoadingFilePreviewView: View {

    private var filename: String

    init(_ filename: String = "") {
        self.filename = filename
    }

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("正在打开 \(filename)...")
                .font(.system(size: 13))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
