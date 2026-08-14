import SwiftUI

/// 插件关于页。
struct MindMapAboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                Text(MindMapLocalization.string("Mind Map", "思维导图"))
                    .font(.title2.weight(.semibold))
            }
            Text(MindMapLocalization.string(
                "A native SwiftUI mind map editor. Grow trees with agent tools in chat or edit directly on the canvas. Layout uses a tidy two-sided tree. Storage is split into project (`.lumi/mind-map`) and app scopes.",
                "原生 SwiftUI 思维导图编辑器。可在聊天中用 Agent 工具生长思维树，或直接在画布上编辑。布局采用双侧整齐树。存储分为项目（`.lumi/mind-map`）与应用两个作用域。"
            ))
            .foregroundStyle(.secondary)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

            LabeledContent(MindMapLocalization.string("Stage", "阶段"), value: "Beta")
            LabeledContent(MindMapLocalization.string("Layout", "布局"), value: "Bilateral tidy tree")
            LabeledContent(MindMapLocalization.string("Storage", "存储"), value: "JSON / Markdown")
        }
        .padding(20)
        .frame(maxWidth: 420, alignment: .leading)
    }
}
