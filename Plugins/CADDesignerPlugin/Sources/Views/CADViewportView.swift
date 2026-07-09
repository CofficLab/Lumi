import SwiftUI

private typealias L = CADDesignerLocalization

/// 3D 视口包装层：嵌入 SceneKit 视口 + 空状态提示。
struct CADViewportView: View {
    @ObservedObject var viewModel: CADWorkspaceViewModel

    var body: some View {
        ZStack {
            CADViewportSceneView(sceneController: viewModel.sceneController) { componentId in
                viewModel.selectComponent(id: componentId)
            }

            if viewModel.document?.components.isEmpty ?? true {
                emptyOverlay
            }

            // 选中态指示
            if let id = viewModel.store.selectedComponentId {
                VStack {
                    Spacer()
                    HStack {
                        Label("已选中：\(id.prefix(8))", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .padding(8)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
    }

    private var emptyOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text(L.string("Empty viewport"))
                .font(.title3.weight(.semibold))

            Text(L.string("Add a profile from the component library to start."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
