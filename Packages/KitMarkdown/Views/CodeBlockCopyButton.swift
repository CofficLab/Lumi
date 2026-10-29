import SwiftUI
import LumiUI

/// 代码块右上角的复制按钮。
///
/// 点击后把代码原文写入系统剪贴板，图标短暂变为对勾作为反馈。
///
/// 复制目标通过 `copyHandler` 注入，默认写系统剪贴板；单元测试注入替身，
/// 避免测试进程污染本机剪贴板。
struct CodeBlockCopyButton: View {
    /// 待复制的代码原文。
    let code: String

    /// 复制执行器。默认写系统剪贴板。
    var copyHandler: @MainActor (String) -> Void = { LumiPasteboard.copyString($0) }

    /// 图标颜色。
    var foregroundColor: Color = .secondary

    /// 复制成功后对勾的停留时长。
    var feedbackDuration: Duration = .seconds(2)

    /// 是否已复制（用于切换图标）。
    @State private var didCopy = false

    /// 鼠标是否悬停（用于提升不透明度）。
    @State private var isHovered = false

    var body: some View {
        Button(action: performCopy) {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(didCopy ? Color.green : foregroundColor)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.secondary.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(
            didCopy
                ? KitMarkdownLocalization.string("Copied", bundle: .module)
                : KitMarkdownLocalization.string("Copy code", bundle: .module)
        )
        .onHover { isHovered = $0 }
        .opacity(isHovered || didCopy ? 1 : 0.55)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    /// 执行复制并给出短暂的成功反馈。
    ///
    /// 暴露为内部方法，便于单元测试直接触发（headless 环境下无法点击按钮）。
    @MainActor
    func performCopy() {
        copyHandler(code)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: feedbackDuration)
            didCopy = false
        }
    }
}

// MARK: - Preview

#Preview("Code Block Copy Button") {
    CodeBlockCopyButton(code: "let a = 1")
        .padding(20)
}
