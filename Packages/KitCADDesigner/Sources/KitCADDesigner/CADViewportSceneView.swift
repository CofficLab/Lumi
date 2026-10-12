import AppKit
import SwiftUI
import SceneKit

/// SwiftUI ↔ SceneKit 桥接（NSViewRepresentable 封装 SCNView）。
///
/// 参考项目 HTMLPreviewView 的 Coordinator 模式：用 SCNView 内置相机控制实现轨道相机，
/// 并通过点击手势做 3D 拾取。
struct CADViewportSceneView: NSViewRepresentable {
    @ObservedObject var sceneController: CADSceneController
    var onPickComponent: (String?) -> Void

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneController.scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.showsStatistics = false
        scnView.backgroundColor = NSColor.windowBackgroundColor

        // 点击拾取
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        scnView.addGestureRecognizer(clickGesture)

        context.coordinator.view = scnView
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        if scnView.scene !== sceneController.scene {
            scnView.scene = sceneController.scene
        }
        context.coordinator.view = scnView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneController: sceneController, onPickComponent: onPickComponent)
    }

    @MainActor
    final class Coordinator: NSObject {
        let sceneController: CADSceneController
        let onPickComponent: (String?) -> Void
        weak var view: SCNView?

        init(sceneController: CADSceneController, onPickComponent: @escaping (String?) -> Void) {
            self.sceneController = sceneController
            self.onPickComponent = onPickComponent
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = view ?? gesture.view as? SCNView else { return }
            let point = gesture.location(in: scnView)
            let hitId = MainActor.assumeIsolated {
                sceneController.hitTest(point: point, in: scnView)
            }
            onPickComponent(hitId)
        }
    }
}
