import LumiUI
import SwiftUI

/// 单个文件内容展示视图
///
/// 根据 `fileURL` 异步加载文件文本内容并以等宽字体展示。
/// 加载失败时展示错误信息；加载中展示进度指示器。
struct FileContentView: View {
    let fileURL: URL
    @State private var content: String?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let content {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            } else if let loadError {
                Text(loadError)
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .task(id: fileURL) {
            content = nil
            loadError = nil
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                loadError = "Unable to load file: \(error.localizedDescription)"
            }
        }
    }
}
