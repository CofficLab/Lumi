import SwiftUI

/// 应用 Logo 视图
///
/// 当前使用内置 SF Symbol 作为默认 Logo。插件贡献的 Logo 将在后续迁移中恢复。
struct LogoView: View {
    let scene: LogoScene

    init(scene: LogoScene = .general) {
        self.scene = scene
    }

    var body: some View {
        Image(systemName: scene == .about ? "app.fill" : "sparkles")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .accessibilityLabel("Logo")
    }
}

/// Logo 使用场景（保留旧命名以兼容调用方）
enum LogoScene {
    case general
    case about
}
