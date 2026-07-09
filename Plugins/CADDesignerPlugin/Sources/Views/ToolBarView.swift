import SwiftUI

private typealias L = CADDesignerLocalization

/// 绘图工具栏：工具切换 + 视图重置。
struct ToolBarView: View {
    @ObservedObject var viewModel: CADWorkspaceViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CADToolKind.allCases) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 18)

            Button {
                viewModel.resetCamera()
            } label: {
                Label(L.string("Reset View"), systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .help(L.string("Reset View"))

            Spacer()

            if let doc = viewModel.document {
                Text("\(doc.components.count) components")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func toolButton(_ tool: CADToolKind) -> some View {
        let isSelected = viewModel.currentTool == tool
        Button {
            viewModel.currentTool = tool
        } label: {
            Label(tool.displayName, systemImage: tool.systemImage)
                .frame(maxWidth: .infinity)
        }
        .modifier(ConditionalButtonStyle(isProminent: isSelected))
        .help(tool.displayName)
    }
}

/// 根据条件切换 ButtonStyle 的修饰符。
private struct ConditionalButtonStyle: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
