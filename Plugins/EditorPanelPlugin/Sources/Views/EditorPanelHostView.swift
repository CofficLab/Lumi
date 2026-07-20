import EditorService
import LumiKernel
import LumiUI
import SwiftUI

public struct EditorPanelHostView: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        if let editorService = kernel.editor?.rawEditorService as? EditorService {
            EditorPanelView(kernel: kernel)
                .environmentObject(editorService)
        } else {
            EditorServiceUnavailableView()
        }
    }
}

struct EditorServiceUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Editor Service Unavailable")
                .font(.headline)
            Text("The editor service is not registered.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}